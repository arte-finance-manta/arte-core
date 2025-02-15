// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IArtha, Id, Pool, Position, PoolParams} from "../src/interfaces/IArtha.sol";
import {MockArtha} from "../src/mocks/MockArtha.sol";
import {MockIrm} from "../src/mocks/MockIrm.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockERC721} from "../src/mocks/MockERC721.sol";
import {MockOracle} from "../src/mocks/MockOracle.sol";

contract MockArthaScript is Script {
    MockArtha public mockArtha;
    MockERC20 public mockUSDC;
    MockERC20 public mockUSDT;
    MockERC721 public mockIP1;
    MockERC721 public mockIP2;
    MockERC721 public mockIP3;
    MockIrm public mockIrm1;
    MockIrm public mockIrm2;
    MockIrm public mockIrm3;
    MockOracle public mockOracle1;
    MockOracle public mockOracle2;
    MockOracle public mockOracle3;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        // deploy loan tokens
        mockUSDT = new MockERC20("USDT", "USDT", 6);
        mockUSDC = new MockERC20("USDC", "USDC", 6);

        // deploy IPs
        mockIP1 = new MockERC721("IP 1", "IP1");

        // deployIRMs
        mockIrm1 = new MockIrm(5e16);
        mockIrm2 = new MockIrm(10e16);
        mockIrm3 = new MockIrm(15e16);

        // deployoracles
        mockOracle1 = new MockOracle(1500e6);
        mockOracle2 = new MockOracle(5300e6);
        mockOracle3 = new MockOracle(7200e6);

        // deploy artha
        mockArtha = new MockArtha();

        // set IRMs
        mockArtha.setInterestRateModel(address(mockIrm1), true);
        mockArtha.setInterestRateModel(address(mockIrm2), true);
        mockArtha.setInterestRateModel(address(mockIrm3), true);

        // set LTVs
        mockArtha.setLTV(90, true);
        mockArtha.setLTV(80, true);
        mockArtha.setLTV(75, true);

        // pool1: IP-1, USDC, Oracle-1, Irm-1, LTV-90, LTH-95
        PoolParams memory poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDC),
            oracle: address(mockOracle1),
            irm: address(mockIrm1),
            ltv: 90,
            lth: 100
        });

        Id pool1 = mockArtha.createPool(poolParams);

        // pool2: IP-1, USDT, Oracle-1, Irm-2, LTV-80, LTH-85
        poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDT),
            oracle: address(mockOracle1),
            irm: address(mockIrm2),
            ltv: 80,
            lth: 85
        });

        Id pool2 = mockArtha.createPool(poolParams);

        // pool3: IP-1, USDC, Oracle-1, Irm-3, LTV-75, LTH-80
        poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDC),
            oracle: address(mockOracle1),
            irm: address(mockIrm3),
            ltv: 75,
            lth: 80
        });

        Id pool3 = mockArtha.createPool(poolParams);

        // pool4: IP-1, USDT, Oracle-1, Irm-1, LTV-75, LTH-80
        poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDT),
            oracle: address(mockOracle1),
            irm: address(mockIrm1),
            ltv: 75,
            lth: 80
        });

        Id pool4 = mockArtha.createPool(poolParams);

        // pool5: IP-1, USDC, Oracle-2, Irm-1, LTV-75, LTH-80
        poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDC),
            oracle: address(mockOracle2),
            irm: address(mockIrm1),
            ltv: 75,
            lth: 80
        });

        Id pool5 = mockArtha.createPool(poolParams);

        // pool6: IP-1, USDT, Oracle-2, Irm-3, LTV-80, LTH-85
        poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDT),
            oracle: address(mockOracle2),
            irm: address(mockIrm3),
            ltv: 80,
            lth: 85
        });

        Id pool6 = mockArtha.createPool(poolParams);

        // pool7: IP-1, USDC, Oracle-2, Irm-3, LTV-80, LTH-85
        poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDC),
            oracle: address(mockOracle2),
            irm: address(mockIrm3),
            ltv: 80,
            lth: 85
        });

        Id pool7 = mockArtha.createPool(poolParams);

        // pool8: IP-1, USDC, Oracle-3, Irm-1, LTV-90, LTH-93
        poolParams = PoolParams({
            collateralToken: address(mockIP1),
            loanToken: address(mockUSDC),
            oracle: address(mockOracle3),
            irm: address(mockIrm1),
            ltv: 90,
            lth: 93
        });

        Id pool8 = mockArtha.createPool(poolParams);

        // mint USDT and USDC
        mockUSDT.mint(account, 100_000e6);
        mockUSDC.mint(account, 100_000e6);

        mockUSDC.approve(address(mockArtha), type(uint256).max);
        mockUSDT.approve(address(mockArtha), type(uint256).max);

        // mint IPs
        mockIP1.mint(account, 1);
        mockIP1.mint(account, 2);
        mockIP1.mint(account, 3);
        mockIP1.mint(account, 4);
        mockIP1.mint(account, 5);
        mockIP1.mint(account, 6);
        mockIP1.mint(account, 7);
        mockIP1.mint(account, 8);

        mockIP1.setApprovalForAll(address(mockArtha), true);

        mockArtha.supply(pool1, 1_900e6, account);
        mockArtha.supply(pool2, 5_700e6, account);
        mockArtha.supply(pool3, 5_000e6, account);
        mockArtha.supply(pool4, 3_000e6, account);
        mockArtha.supply(pool5, 1_300e6, account);
        mockArtha.supply(pool6, 2_100e6, account);
        mockArtha.supply(pool7, 5_500e6, account);
        mockArtha.supply(pool8, 3_100e6, account);

        // IP 1
        mockArtha.supplyCollateralAndBorrow(pool1, 1, 200e6, account, account);
        mockArtha.supplyCollateralAndBorrow(pool2, 2, 300e6, account, account);
        mockArtha.supplyCollateralAndBorrow(pool2, 5, 300e6, account, account);
        mockArtha.supplyCollateralAndBorrow(pool2, 6, 300e6, account, account);
        mockArtha.repay(pool1, 1, 50e6, account);

        console.log("mock USDC deployed at", address(mockUSDC));
        console.log("mock USDT deployed at", address(mockUSDT));
        // oracles
        console.log("mock Oracle 1 deployed at", address(mockOracle1));
        console.log("mock Oracle 2 deployed at", address(mockOracle2));
        console.log("mock Oracle 3 deployed at", address(mockOracle3));
        // IRMs
        console.log("mock Irm 1 deployed at", address(mockIrm1));
        console.log("mock Irm 2 deployed at", address(mockIrm2));
        console.log("mock Irm 3 deployed at", address(mockIrm3));
        // IPs
        console.log("mock IP 1 deployed at", address(mockIP1));
        // MockArtha
        console.log("MockArtha deployed at", address(mockArtha));
        // pools
        console.log("Pool 1 created at", vm.toString(Id.unwrap(pool1)));
        console.log("Pool 2 created at", vm.toString(Id.unwrap(pool2)));
        console.log("Pool 3 created at", vm.toString(Id.unwrap(pool3)));
        console.log("Pool 4 created at", vm.toString(Id.unwrap(pool4)));
        console.log("Pool 5 created at", vm.toString(Id.unwrap(pool5)));
        console.log("Pool 6 created at", vm.toString(Id.unwrap(pool6)));
        console.log("Pool 7 created at", vm.toString(Id.unwrap(pool7)));
        console.log("Pool 8 created at", vm.toString(Id.unwrap(pool8)));

        vm.stopBroadcast();
    }
}
