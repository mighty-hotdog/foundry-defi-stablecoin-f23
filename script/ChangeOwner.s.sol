// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract ChangeOwner is Script {
    DecentralizedStableCoin public coin;
    address public engine;
    address public deployer;

    function run() external 
        returns (
            DecentralizedStableCoin,
            address)
    {
        populateAddresses(vm.envAddress("DSC_DEPLOYED_ADDRESS"),vm.envAddress("DSC_ENGINE_DEPLOYED_ADDRESS"));
        vm.startBroadcast(deployer);
        coin.transferOwnership(engine);
        vm.stopBroadcast();

        return (coin,engine);
    }

    function populateAddresses(address DSCAddr, address DSCEngineAddr) public {
        // this project assumes deployment only to mainnet, sepolia testnet, and Anvil
        if (block.chainid == vm.envUint("ETH_MAINNET_CHAINID")) {
            coin = DecentralizedStableCoin(vm.envAddress("DSC_DEPLOYED_ADDRESS"));
            engine = vm.envAddress("DSC_ENGINE_DEPLOYED_ADDRESS");
        } else if (block.chainid == vm.envUint("ETH_SEPOLIA_CHAINID")) {
            coin = DecentralizedStableCoin(vm.envAddress("DSC_DEPLOYED_ADDRESS"));
            engine = vm.envAddress("DSC_ENGINE_DEPLOYED_ADDRESS");
        } else {
            coin = DecentralizedStableCoin(DSCAddr);
            engine = DSCEngineAddr;
        }
        deployer = vm.envAddress("SENDER_ADDRESS");
    }
}