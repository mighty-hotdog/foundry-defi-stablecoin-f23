// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAggregatorV3} from "../test/mocks/MockAggregatorV3.sol";
import {ChainConfigurator} from "./ChainConfigurator.s.sol";

contract DeployDSCEngine is Script {
    /* Errors */
    error DeployDSCEngine__DscTokenAddressCannotBeZero();

    /* State Variables */
    ChainConfigurator public chainConfig;

    /* Functions */
    function run(address dscToken) external returns (DSCEngine,ChainConfigurator) {
        if (dscToken == address(0)) {
            revert DeployDSCEngine__DscTokenAddressCannotBeZero();
        }
        chainConfig = new ChainConfigurator();
        address[] memory allowedCollateralTokenAddresses = new address[](2);
        address[] memory collateralTokenPriceFeedAddresses = new address[](2);
        uint256[] memory priceFeedPrecision = new uint256[](2);
        // this definition doesn't work
        //address[2] memory allowedCollateralTokenAddresses = [weth,wbtc];
        //address[2] memory collateralTokenPriceFeedAddresses = [wethPriceFeed,wbtcPriceFeed];
        (
            allowedCollateralTokenAddresses[0],
            allowedCollateralTokenAddresses[1],
            collateralTokenPriceFeedAddresses[0],
            collateralTokenPriceFeedAddresses[1],
            priceFeedPrecision[0],
            priceFeedPrecision[1]
        ) = chainConfig.s_activeChainConfig();
        uint256 thresholdPercent = vm.envUint("THRESHOLD_PERCENT");
        // deploy DSCEngine
        vm.startBroadcast();
        DSCEngine engine = new DSCEngine(
            allowedCollateralTokenAddresses,
            collateralTokenPriceFeedAddresses,
            priceFeedPrecision,
            dscToken,
            thresholdPercent);
        vm.stopBroadcast();
        // transfer ownership from initial owner to the DSCEngine
        vm.startBroadcast(DecentralizedStableCoin(dscToken).owner());
        DecentralizedStableCoin(dscToken).transferOwnership(address(engine));
        vm.stopBroadcast();
        return (engine,chainConfig);
    }
}