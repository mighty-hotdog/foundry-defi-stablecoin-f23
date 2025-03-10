// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ChainConfigurator} from "./ChainConfigurator.s.sol";

contract DeployDSC is Script {
    DecentralizedStableCoin public coin;
    DSCEngine public engine;
    ChainConfigurator public config;

    function run() external 
        returns (
            DecentralizedStableCoin,
            DSCEngine,
            ChainConfigurator) 
    {
        // All deployments to be done by a single deployer account
        //  which will initiate and sign all the necessary transactions.
        //vm.startBroadcast();
        config = new ChainConfigurator();
        //vm.stopBroadcast();

        address[] memory tokens = new address[](2);
        address[] memory feeds = new address[](2);
        uint256[] memory precision = new uint256[](2);
        (
            tokens[0],
            tokens[1],
            feeds[0],
            feeds[1],
            precision[0],
            precision[1]
        ) = config.s_activeChainConfig();
        uint256 threshold = vm.envUint("THRESHOLD_PERCENT");

        address deployer = vm.envAddress("SENDER_ADDRESS");
        vm.startBroadcast(deployer);
        coin = new DecentralizedStableCoin(deployer);
        engine = new DSCEngine(
            tokens,
            feeds,
            precision,
            address(coin),
            threshold);

        // when deploying to mainnet or testnet, this transfer ownership call will fail because
        //  the contract deployment transaction is still pending by the time of this call.
        // solution is to wait for the block to be confirmed (~15 seconds) and then call the
        //  transfer ownership from another script - ChangeOwner.s.sol - using the contract
        //  addresses returned by this script
        //coin.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (coin,engine,config);
    }
}