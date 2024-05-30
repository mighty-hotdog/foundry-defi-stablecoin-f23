// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAggregatorV3} from "../test/mocks/MockAggregatorV3.sol";

contract DeployDSCEngine is Script {
    /* Errors */
    error DeployDSCEngine__InvalidTokenAddress();

    /* Functions */
    function run(address dscToken) external returns (DSCEngine) {
        if (dscToken == address(0)) {
            revert DeployDSCEngine__InvalidTokenAddress();
        }
        address[] memory allowedCollateralTokenAddresses = new address[](2);
        address[] memory collateralTokenPriceFeedAddresses = new address[](2);
        uint256 thresholdPercent = vm.envUint("THRESHOLD_PERCENT");

        if (block.chainid == vm.envUint("ETH_MAINNET_CHAINID")) {
            allowedCollateralTokenAddresses[0] = vm.envAddress("WETH_ADDRESS_MAINNET");
            allowedCollateralTokenAddresses[1] = vm.envAddress("WBTC_ADDRESS_MAINNET");
            collateralTokenPriceFeedAddresses[0] = vm.envAddress("WETH_PRICE_FEED_ADDRESS_MAINNET");
            collateralTokenPriceFeedAddresses[1] = vm.envAddress("WBTC_PRICE_FEED_ADDRESS_MAINNET");
        } else if (block.chainid == vm.envUint("ETH_SEPOLIA_CHAINID")) {
            allowedCollateralTokenAddresses[0] = vm.envAddress("WETH_ADDRESS_SEPOLIA");
            allowedCollateralTokenAddresses[1] = vm.envAddress("WBTC_ADDRESS_SEPOLIA");
            collateralTokenPriceFeedAddresses[0] = vm.envAddress("WETH_PRICE_FEED_ADDRESS_SEPOLIA");
            collateralTokenPriceFeedAddresses[1] = vm.envAddress("WBTC_PRICE_FEED_ADDRESS_SEPOLIA");
        } else {
            // deploy mock ERC20 token for wETH and for wBTC
            vm.startBroadcast();
            ERC20Mock mockWETH = new ERC20Mock();
            ERC20Mock mockWBTC = new ERC20Mock();
            // deploy mock Chainlink AggregatorV3Interface for wETH pricefeed and for wBTC pricefeed
            MockAggregatorV3 mockEthPriceFeed = new MockAggregatorV3("CHAINLINK_DATAFEED_ANSWER_ETH_USD");
            MockAggregatorV3 mockBtcPriceFeed = new MockAggregatorV3("CHAINLINK_DATAFEED_ANSWER_BTC_USD");
            vm.stopBroadcast();
            // populate the 2 arrays with their respective addresses
            allowedCollateralTokenAddresses[0] = address(mockWETH);
            allowedCollateralTokenAddresses[1] = address(mockWBTC);
            collateralTokenPriceFeedAddresses[0] = address(mockEthPriceFeed);
            collateralTokenPriceFeedAddresses[1] = address(mockBtcPriceFeed);
        }

        vm.startBroadcast();
        DSCEngine engine = new DSCEngine(
            allowedCollateralTokenAddresses,
            collateralTokenPriceFeedAddresses,
            dscToken,thresholdPercent);
        // transfer ownership from original owner (test script) to the DSCEngine
        DecentralizedStableCoin(dscToken).transferOwnership(address(engine));
        vm.stopBroadcast();
        return engine;
    }
}