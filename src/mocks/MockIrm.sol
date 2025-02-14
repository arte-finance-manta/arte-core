// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Id, Pool} from "../interfaces/IArtha.sol";
import {Iirm} from "../interfaces/Iirm.sol";

contract MockIrm is Iirm {
    uint256 public rate;

    constructor(uint256 _rate) {
        rate = _rate;
    }

    function getBorrowRate(Id id, Pool memory pool) external view returns (uint256) {
        return rate;
    }
}
