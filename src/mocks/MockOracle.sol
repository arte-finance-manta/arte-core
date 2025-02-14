// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Id} from "../interfaces/IArtha.sol";

contract MockOracle {
    uint256 public price;

    constructor(uint256 _price) {
        price = _price;
    }

    function getPrice(uint256) external view returns (uint256) {
        return price;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }
}
