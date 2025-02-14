// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IArtha, Id, Pool, Position, PoolParams} from "./interfaces/IArtha.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Iirm} from "./interfaces/Iirm.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";

contract Artha is Ownable, IArtha, IERC721Receiver {
    using SafeERC20 for IERC20;
    using Math for uint256;

    error IRMNotExist();
    error LTVNotExist();
    error PoolAlreadyCreated();
    error PoolNotExist();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error NotTokenOwner();
    error DebtNotZero();
    error LTVGreaterThanLTH();
    error NotAuctionable();
    error AuctionAlreadyEnded();
    error AuctionNotYetEnded();
    error BidTooLow();
    error LTVExceeded();
    error NotAllowed();

    event PoolCreated(Id id, PoolParams poolParams);
    event InterestRateModelChanged(address irm, bool enabled);
    event LTVChanged(uint256 ltv, bool enabled);
    event SupplyCollateral(Id id, uint256 tokenId, address sender, address onBehalOf);
    event WithdrawCollateral(Id id, uint256 tokenId, address sender, address onBehalfOf, address receiver);
    event Supply(Id id, address sender, address onBehalfOf, uint256 amount, uint256 shares);
    event Withdraw(Id id, address sender, address onBehalfOf, address receiver, uint256 amount, uint256 shares);
    event Borrow(
        Id id, uint256 tokenId, address sender, address onBehalfOf, address receiver, uint256 amount, uint256 shares
    );
    event Repay(Id id, uint256 tokenId, address sender, address onBehalfOf, uint256 amount, uint256 shares);
    event Bid(Id id, uint256 tokenId, address bidder, uint256 amount);
    event AuctionSettled(Id id, uint256 tokenId, address bidder, uint256 amount);
    event Accrued(Id id, uint256 borrowRate, uint256 interest, uint256 feeShares);
    event FlashLoan(address indexed caller, address indexed token, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    uint256 public constant INTEREST_SCALED = 1e18;
    uint256 public constant AUCTION_TIME = 24 hours;

    mapping(address irm => bool enabled) public interestRateModels;
    mapping(uint256 ltv => bool enabled) public ltvs;
    mapping(Id => Pool) public pools;
    mapping(Id => mapping(address owner => uint256 shares)) public supplies;
    mapping(Id => mapping(uint256 tokenId => Position)) public positions;
    mapping(address owner => mapping(address operator => bool isOperator)) public operators;

    constructor() Ownable(msg.sender) {}

    function getPositon(Id id, uint256 tokenId) external view returns (uint256, address) {
        return (positions[id][tokenId].borrowShares, positions[id][tokenId].owner);
    }

    function setInterestRateModel(address irm, bool enabled) external onlyOwner {
        interestRateModels[irm] = enabled;
        emit InterestRateModelChanged(irm, enabled);
    }

    function setLTV(uint256 ltv, bool enabled) external onlyOwner {
        if (ltv > 100) revert LTVExceeded();
        ltvs[ltv] = enabled;
        emit LTVChanged(ltv, enabled);
    }

    function isPoolExist(Id id) external view returns (bool) {
        return pools[id].lastAccrued != 0;
    }

    function createPool(PoolParams memory poolParams) external returns (Id) {
        Id id = computeId(poolParams);

        if (!interestRateModels[poolParams.irm]) revert IRMNotExist();
        if (!ltvs[poolParams.ltv]) revert LTVNotExist();

        Pool storage pool = pools[id];
        if (pool.lastAccrued != 0) revert PoolAlreadyCreated();
        if (poolParams.ltv > poolParams.lth) revert LTVGreaterThanLTH();

        pool.collateralToken = poolParams.collateralToken;
        pool.loanToken = poolParams.loanToken;
        pool.oracle = poolParams.oracle;
        pool.irm = poolParams.irm;
        pool.ltv = poolParams.ltv;
        pool.lth = poolParams.lth;
        pool.lastAccrued = block.timestamp;

        emit PoolCreated(id, poolParams);

        return id;
    }

    function computeId(PoolParams memory poolParams) public pure returns (Id id) {
        return Id.wrap(keccak256(abi.encode(poolParams)));
    }

    function supply(Id id, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        Pool storage pool = pools[id];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        if (onBehalfOf == address(0)) revert ZeroAddress();

        _accrue(id);

        uint256 shares = 0;
        if (pools[id].totalSupplyShares == 0) {
            shares = amount;
        } else {
            shares = amount.mulDiv(pools[id].totalSupplyShares, pools[id].totalSupplyAssets);
        }

        // note:amount.mulDiv(pools[id].totalSupplyShares + VIRTUAL_SHARES, pools[id].totalSupplyAssets + 1, Math.Rounding.Floor);

        supplies[id][onBehalfOf] += shares;
        pool.totalSupplyShares += shares;
        pool.totalSupplyAssets += amount;

        emit Supply(id, msg.sender, onBehalfOf, amount, shares);

        IERC20(pool.loanToken).safeTransferFrom(msg.sender, address(this), amount);

        return (amount, shares);
    }

    function withdraw(Id id, uint256 shares, address onBehalfOf, address receiver)
        external
        returns (uint256, uint256)
    {
        Pool storage pool = pools[id];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        if (receiver == address(0)) revert ZeroAddress();
        if (!_isOperator(onBehalfOf)) revert NotAllowed();

        _accrue(id);

        uint256 amount = shares.mulDiv(pool.totalSupplyAssets, pool.totalSupplyShares);

        // note: uint256 amount = shares.mulDiv(pools[id].totalSupplyAssets + 1, pools[id].totalSupplyShares + VIRTUAL_SHARES, Math.Rounding.Floor);

        supplies[id][onBehalfOf] -= shares;
        pool.totalSupplyShares -= shares;
        pool.totalSupplyAssets -= amount;

        if (pool.totalBorrowAssets >= pool.totalSupplyAssets) revert InsufficientLiquidity();

        emit Withdraw(id, msg.sender, onBehalfOf, receiver, amount, shares);

        IERC20(pool.loanToken).safeTransfer(receiver, amount);

        return (amount, shares);
    }

    function borrow(Id id, uint256 tokenId, uint256 amount, address onBehalfOf, address receiver)
        public
        returns (uint256, uint256)
    {
        Pool storage pool = pools[id];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        if (receiver == address(0)) revert ZeroAddress();
        if (!_isOperator(onBehalfOf)) revert NotAllowed();

        _accrue(id);

        //note: uint256 shares = amount.mulDiv(pools[id].totalBorrowShares + VIRTUAL_SHARES, pools[id].totalBorrowAssets + 1, Math.Rounding.Ceil);
        uint256 shares = 0;
        if (pools[id].totalBorrowShares == 0) {
            shares = amount;
        } else {
            shares = amount.mulDiv(pool.totalBorrowShares, pool.totalBorrowAssets);
        }

        Position storage position = positions[id][tokenId];
        position.borrowShares += shares;
        pool.totalBorrowShares += shares;
        pool.totalBorrowAssets += amount;

        if (_isMaxBorrow(pool, position, tokenId)) revert InsufficientCollateral();
        if (pool.totalBorrowAssets >= pool.totalSupplyAssets) revert InsufficientLiquidity();

        emit Borrow(id, tokenId, msg.sender, onBehalfOf, receiver, amount, shares);

        IERC20(pool.loanToken).safeTransfer(receiver, amount);

        return (amount, shares);
    }

    function repay(Id id, uint256 tokenId, uint256 shares, address onBehalfOf) external returns (uint256, uint256) {
        Pool storage pool = pools[id];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        if (onBehalfOf == address(0)) revert ZeroAddress();

        _accrue(id);

        // note:uint256 shares = amount.mulDiv( pools[id].totalBorrowShares + VIRTUAL_SHARES, pools[id].totalBorrowAssets + 1, Math.Rounding.Floor );
        uint256 amount = shares.mulDiv(pool.totalBorrowAssets, pool.totalBorrowShares);

        positions[id][tokenId].borrowShares -= shares;
        pool.totalBorrowShares -= shares;
        pool.totalBorrowAssets -= amount;

        emit Repay(id, tokenId, msg.sender, onBehalfOf, amount, shares);

        IERC20(pool.loanToken).safeTransferFrom(msg.sender, address(this), amount);

        return (amount, shares);
    }

    function supplyCollateral(Id id, uint256 tokenId, address onBehalfOf) public {
        Pool storage pool = pools[id];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        if (onBehalfOf == address(0)) revert ZeroAddress();

        // TODO: fix onBehalfOf
        if (IERC721(pool.collateralToken).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();

        positions[id][tokenId].owner = msg.sender;

        IERC721(pool.collateralToken).safeTransferFrom(msg.sender, address(this), tokenId);

        emit SupplyCollateral(id, tokenId, msg.sender, onBehalfOf);
    }

    function supplyCollateralAndBorrow(Id id, uint256 tokenId, uint256 amount, address onBehalfOf, address receiver)
        external
    {
        supplyCollateral(id, tokenId, onBehalfOf);
        borrow(id, tokenId, amount, onBehalfOf, receiver);
    }

    function withdrawRoyalty(Id id, uint256 tokenId, address onBehalfOf, address receiver) external {}

    function withdrawCollateral(Id id, uint256 tokenId, address onBehalfOf, address receiver) external {
        Pool storage pool = pools[id];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        if (receiver == address(0)) revert ZeroAddress();
        if (positions[id][tokenId].borrowShares != 0) revert DebtNotZero();
        if (!_isOperator(onBehalfOf)) revert NotAllowed();

        delete positions[id][tokenId];

        IERC721(pool.collateralToken).safeTransferFrom(address(this), receiver, tokenId);

        emit WithdrawCollateral(id, tokenId, msg.sender, onBehalfOf, receiver);
    }

    // =============================================================
    //                         Auction
    // =============================================================

    function bid(Id id, uint256 tokenId, uint256 amount) external {
        Pool storage pool = pools[id];
        Position storage position = positions[id][tokenId];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        // TODO: fix the validations
        if (!_isHealthy(pool, position, tokenId)) revert NotAuctionable();
        if (position.endTime > block.timestamp) revert AuctionAlreadyEnded();

        if (amount <= position.bid) revert BidTooLow();

        address previousBidder = position.bidder;
        uint256 previousBid = position.bid;

        position.bid = amount;
        position.bidder = msg.sender;
        if (position.endTime == 0) {
            position.endTime = block.timestamp + AUCTION_TIME;
        }

        IERC20(pool.loanToken).safeTransferFrom(msg.sender, address(this), amount);

        if (previousBidder != address(0)) {
            IERC20(pool.loanToken).safeTransfer(previousBidder, previousBid);
        }

        emit Bid(id, tokenId, msg.sender, amount);
    }

    function settleAuction(Id id, uint256 tokenId) external {
        Pool storage pool = pools[id];
        Position storage position = positions[id][tokenId];
        if (pool.lastAccrued == 0) revert PoolNotExist();
        if (position.endTime < block.timestamp) revert AuctionNotYetEnded();

        IERC721(pool.collateralToken).safeTransferFrom(address(this), position.bidder, tokenId);

        emit AuctionSettled(id, tokenId, position.bidder, position.bid);

        delete positions[id][tokenId];
    }

    function accrueInterest(Id id) external {
        _accrue(id);
    }

    // =============================================================
    //                         Flash Loan
    // =============================================================

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        if (amount == 0) revert ZeroAmount();
        require(
            receiver.onFlashLoan(msg.sender, token, amount, 0, data) == keccak256("ERC3156FlashBorrower.onFlashLoan"),
            "IERC3156: Callback failed"
        );

        IERC20(token).safeTransfer(address(receiver), amount);

        receiver.onFlashLoan(msg.sender, token, amount, 0, data);

        IERC20(token).safeTransferFrom(address(receiver), address(this), amount);

        emit FlashLoan(address(receiver), token, amount);

        return true;
    }

    // =============================================================
    //                         Operator
    // =============================================================

    function _isOperator(address onBehalf) internal view returns (bool) {
        return msg.sender == onBehalf || operators[onBehalf][msg.sender];
    }

    function setOperator(address operator, bool approved) public virtual returns (bool) {
        operators[msg.sender][operator] = approved;

        emit OperatorSet(msg.sender, operator, approved);

        return true;
    }

    // =============================================================
    //                         Internals
    // =============================================================

    function _accrue(Id id) internal {
        Pool storage pool = pools[id];
        uint256 timeElapsed = block.timestamp - pool.lastAccrued;
        if (timeElapsed == 0) return;

        uint256 borrowRate = Iirm(pool.irm).getBorrowRate(id, pool);
        // TODO: fix the rounding
        uint256 accumulatedInterest = pool.totalBorrowAssets * borrowRate * timeElapsed / 365 days / INTEREST_SCALED;
        pool.totalBorrowAssets += accumulatedInterest;
        pool.totalSupplyAssets += accumulatedInterest;

        pool.lastAccrued = block.timestamp;

        emit Accrued(id, borrowRate, accumulatedInterest, 0);
    }

    function _isHealthy(Pool memory pool, Position memory position, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        uint256 collateralValue = IOracle(pool.oracle).getPrice(tokenId);

        uint256 borrowed = position.borrowShares.mulDiv(pool.totalBorrowAssets, pool.totalBorrowShares);
        uint256 liquidationValue = collateralValue * pool.lth / 100;

        return borrowed >= liquidationValue;
    }

    function _isMaxBorrow(Pool memory pool, Position memory position, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        uint256 collateralValue = IOracle(pool.oracle).getPrice(tokenId);

        uint256 borrowed = position.borrowShares.mulDiv(pool.totalBorrowAssets, pool.totalBorrowShares);
        uint256 maxBorrow = collateralValue * pool.ltv / 100;

        return borrowed > maxBorrow;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
