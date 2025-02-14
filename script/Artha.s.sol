// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IArtha, Id, Pool, Position, PoolParams} from "../src/interfaces/IArtha.sol";
import {Artha} from "../src/Artha.sol";
import {MockIrm} from "../src/mocks/MockIrm.sol";
import {MockERC721} from "../src/mocks/MockERC721.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract ArthaScript is Script {
    Artha public artha;
    MockIrm public mockIrm;
    MockERC20 public mockUSDC;
    MockERC721 public ip1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        mockUSDC = new MockERC20("USDC", "USDC", 6);
        ip1 = new MockERC721("IP 1", "IP1");
        mockIrm = new MockIrm(5e16);
        artha = new Artha();

        artha.setInterestRateModel(address(mockIrm), true);
        artha.setLTV(90, true);
        artha.setLTV(80, true);

        PoolParams memory pool1Params = PoolParams({
            collateralToken: address(ip1),
            loanToken: address(mockUSDC),
            oracle: address(0),
            irm: address(mockIrm),
            ltv: 90,
            lth: 100
        });

        Id pool1 = artha.createPool(pool1Params);

        console.log("mock USDC deployed at", address(mockUSDC));
        console.log("mock Irm deployed at", address(mockIrm));
        console.log("mock IP deployed at", address(ip1));
        console.log("Artha deployed at", address(artha));
        console.log("Pool 1 created at =");
        console.logBytes32(Id.unwrap(pool1));

        vm.stopBroadcast();
    }
}
