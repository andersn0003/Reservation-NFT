// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/ReservNFT.sol";

contract DeployReservNFT is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new ReservNFT();

        vm.stopBroadcast();
    }
}
