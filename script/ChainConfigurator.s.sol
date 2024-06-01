// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAggregatorV3} from "../test/mocks/MockAggregatorV3.sol";

contract ChainConfigurator is Script {
    struct ChainConfig {
        address wETH;
        address wBTC;
        address wETHPriceFeed;
        address wBTCPriceFeed;
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
        return ChainConfig({
            wETH: vm.envAddress("WETH_ADDRESS_MAINNET"),
            wBTC: vm.envAddress("WBTC_ADDRESS_MAINNET"),
            wETHPriceFeed: vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET"),
            wBTCPriceFeed: vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET")
        });
    }
    function getSepoliaChainConfig() internal view returns (ChainConfig memory) {
        return ChainConfig({
            wETH: vm.envAddress("WETH_ADDRESS_SEPOLIA"),
            wBTC: vm.envAddress("WBTC_ADDRESS_SEPOLIA"),
            wETHPriceFeed: vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA"),
            wBTCPriceFeed: vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA")
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
        // deploy mock Chainlink AggregatorV3Interface for wETH pricefeed and for wBTC pricefeed
        MockAggregatorV3 mockEthPriceFeed = new MockAggregatorV3("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD");
        MockAggregatorV3 mockBtcPriceFeed = new MockAggregatorV3("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD");
        vm.stopBroadcast();
        return ChainConfig({
            wETH: address(mockWETH),
            wBTC: address(mockWBTC),
            wETHPriceFeed: address(mockEthPriceFeed),
            wBTCPriceFeed: address(mockBtcPriceFeed)
        });
    }
}