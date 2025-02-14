// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IOracle {
    function getPrice(uint256) external view returns (uint256);
}
