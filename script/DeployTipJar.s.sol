// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TipJar} from "../src/TipJar.sol";

contract DeployTipJar is Script {
    function run() external returns (TipJar) {
        vm.startBroadcast();
        TipJar jar = new TipJar();
        vm.stopBroadcast();

        console.log("TipJar deployed at:", address(jar));
        return jar;
    }
}
