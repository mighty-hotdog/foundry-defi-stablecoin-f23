// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAggregatorV3} from "../test/mocks/MockAggregatorV3.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {FeedRegistryInterface} from "@chainlink/contracts/v0.8/interfaces/FeedRegistryInterface.sol";
import {Denominations} from "@chainlink/contracts/v0.8/Denominations.sol";

contract ChainConfigurator is Script {
    struct ChainConfig {
        address wETH;
        address wBTC;
        address wETHPriceFeed;
        address wBTCPriceFeed;
        uint256 wETHPriceFeedPrecision;
        uint256 wBTCPriceFeedPrecision;
    }

    ChainConfig public s_activeChainConfig;

    constructor() {
        if (block.chainid == vm.envUint("ETH_MAINNET_CHAINID")) {
            s_activeChainConfig = getMainnetChainConfig();
        } else if (block.chainid == vm.envUint("ETH_SEPOLIA_CHAINID")) {
            s_activeChainConfig = getSepoliaChainConfig();
        } else {
            s_activeChainConfig = getAnvilChainConfig();
        }
    }
    function getMainnetChainConfig() internal view returns (ChainConfig memory) {
        //address feedRegistry = vm.envAddress("CHAINLINK_FEED_REGISTRY_ADDRESS_MAINNET");
        address wethPriceFeedAddress = vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET");
        address wbtcPriceFeedAddress = vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET");
        return ChainConfig({
            wETH: vm.envAddress("WETH_ADDRESS_MAINNET"),
            wBTC: vm.envAddress("WBTC_ADDRESS_MAINNET"),
            /* More work needed to make this work with Chainlink Feed Registry
            wETHPriceFeed: address(FeedRegistryInterface(feedRegistry).getFeed(
                Denominations.ETH,Denominations.USD)),
            wBTCPriceFeed: address(FeedRegistryInterface(feedRegistry).getFeed(
                Denominations.BTC,Denominations.USD)),
            wETHPriceFeedPrecision: FeedRegistryInterface(feedRegistry).decimals(Denominations.ETH,Denominations.USD),
            wBTCPriceFeedPrecision: FeedRegistryInterface(feedRegistry).decimals(Denominations.BTC,Denominations.USD)
            */
            wETHPriceFeed: wethPriceFeedAddress,
            wBTCPriceFeed: wbtcPriceFeedAddress,
            wETHPriceFeedPrecision: AggregatorV3Interface(wethPriceFeedAddress).decimals(),
            wBTCPriceFeedPrecision: AggregatorV3Interface(wbtcPriceFeedAddress).decimals()
            /* Deprecated. Use AggregatorV3Interface.decimals() instead.
            wETHPriceFeedPrecision: vm.envUint("WETH_CHAINLINK_PRICE_FEED_PRECISION_MAINNET"),
            wBTCPriceFeedPrecision: vm.envUint("WBTC_CHAINLINK_PRICE_FEED_PRECISION_MAINNET")
            */
        });
    }
    function getSepoliaChainConfig() internal view returns (ChainConfig memory) {
        address wethPriceFeedAddress = vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA");
        address wbtcPriceFeedAddress = vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA");
        return ChainConfig({
            wETH: vm.envAddress("WETH_ADDRESS_SEPOLIA"),
            wBTC: vm.envAddress("WBTC_ADDRESS_SEPOLIA"),
            wETHPriceFeed: wethPriceFeedAddress,
            wBTCPriceFeed: wbtcPriceFeedAddress,
            wETHPriceFeedPrecision: AggregatorV3Interface(wethPriceFeedAddress).decimals(),
            wBTCPriceFeedPrecision: AggregatorV3Interface(wbtcPriceFeedAddress).decimals()
            /* Deprecated. Use AggregatorV3Interface.decimals() instead.
            wETHPriceFeedPrecision: vm.envUint("WETH_CHAINLINK_PRICE_FEED_PRECISION_SEPOLIA"),
            wBTCPriceFeedPrecision: vm.envUint("WBTC_CHAINLINK_PRICE_FEED_PRECISION_SEPOLIA")
            */
        });
    }
    function getAnvilChainConfig() internal returns (ChainConfig memory) {
        if (s_activeChainConfig.wETH != address(0)) {
            return s_activeChainConfig;
        }
        // deploy mock ERC20 token for wETH and for wBTC
        vm.startBroadcast();
        ERC20Mock mockWETH = new ERC20Mock();
        ERC20Mock mockWBTC = new ERC20Mock();
        // deploy mock Chainlink AggregatorV3Interface for wETH and wBTC pricefeeds
        MockAggregatorV3 mockEthPriceFeed = new MockAggregatorV3(
            MockAggregatorV3.ConstructorParams({
                description: vm.envString("CHAINLINK_MOCK_PRICE_FEED_DESCRIPTION"),
                version: vm.envUint("CHAINLINK_MOCK_PRICE_FEED_VERSION"),
                decimals: uint8(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD")),
                answer: vm.envInt("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD")
            }));
        MockAggregatorV3 mockBtcPriceFeed = new MockAggregatorV3(
            MockAggregatorV3.ConstructorParams({
                description: vm.envString("CHAINLINK_MOCK_PRICE_FEED_DESCRIPTION"),
                version: vm.envUint("CHAINLINK_MOCK_PRICE_FEED_VERSION"),
                decimals: uint8(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD")),
                answer: vm.envInt("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD")
            }));
        vm.stopBroadcast();
        return ChainConfig({
            wETH: address(mockWETH),
            wBTC: address(mockWBTC),
            wETHPriceFeed: address(mockEthPriceFeed),
            wBTCPriceFeed: address(mockBtcPriceFeed),
            wETHPriceFeedPrecision: mockEthPriceFeed.decimals(),
            wBTCPriceFeedPrecision: mockBtcPriceFeed.decimals()
        });
    }
}