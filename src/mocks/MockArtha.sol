// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Artha, Id, Pool, Position} from "../Artha.sol";

contract MockArtha is Artha {
    mapping(Id => mapping(uint256 => bool)) public unhealthyList;

    function setUnhealthy(Id id, uint256 tokenId) public {
        unhealthyList[id][tokenId] = true;
    }

    function _isHealthy(Pool memory pool, Position memory position, uint256 tokenId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        Id id = Id.wrap(
            keccak256(abi.encode(pool.collateralToken, pool.loanToken, pool.oracle, pool.irm, pool.ltv, pool.lth))
        );
        if (unhealthyList[id][tokenId]) {
            return false;
        } else {
            return true;
        }
    }
}
