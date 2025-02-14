// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Id, Pool} from "./IArtha.sol";

interface Iirm {
    function getBorrowRate(Id id, Pool memory pool) external returns (uint256);
}
