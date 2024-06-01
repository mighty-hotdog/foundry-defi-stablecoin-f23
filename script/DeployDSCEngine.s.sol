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
    /*
    // created ChainConfigurator to manage and provide access to these values
    // made these mock variables state public to facilitate testing
    ERC20Mock public mockWETH;
    ERC20Mock public mockWBTC;
    MockAggregatorV3 public mockEthPriceFeed;
    MockAggregatorV3 public mockBtcPriceFeed;
    */

    /* Functions */
    function run(address dscToken) external returns (DSCEngine,ChainConfigurator) {
        if (dscToken == address(0)) {
            revert DeployDSCEngine__DscTokenAddressCannotBeZero();
        }
        chainConfig = new ChainConfigurator();
        address[] memory allowedCollateralTokenAddresses = new address[](2);
        address[] memory collateralTokenPriceFeedAddresses = new address[](2);
        (
            allowedCollateralTokenAddresses[0],
            allowedCollateralTokenAddresses[1],
            collateralTokenPriceFeedAddresses[0],
            collateralTokenPriceFeedAddresses[1]
        ) = chainConfig.s_activeChainConfig();
        uint256 thresholdPercent = vm.envUint("THRESHOLD_PERCENT");
        // this definition doesn't work
        //address[2] memory allowedCollateralTokenAddresses = [weth,wbtc];
        //address[2] memory collateralTokenPriceFeedAddresses = [wethPriceFeed,wbtcPriceFeed];
        
        /*
        address[] memory allowedCollateralTokenAddresses = new address[](2);
        address[] memory collateralTokenPriceFeedAddresses = new address[](2);
        uint256 thresholdPercent = vm.envUint("THRESHOLD_PERCENT");

        if (block.chainid == vm.envUint("ETH_MAINNET_CHAINID")) {
            allowedCollateralTokenAddresses[0] = vm.envAddress("WETH_ADDRESS_MAINNET");
            allowedCollateralTokenAddresses[1] = vm.envAddress("WBTC_ADDRESS_MAINNET");
            collateralTokenPriceFeedAddresses[0] = vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET");
            collateralTokenPriceFeedAddresses[1] = vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET");
        } else if (block.chainid == vm.envUint("ETH_SEPOLIA_CHAINID")) {
            allowedCollateralTokenAddresses[0] = vm.envAddress("WETH_ADDRESS_SEPOLIA");
            allowedCollateralTokenAddresses[1] = vm.envAddress("WBTC_ADDRESS_SEPOLIA");
            collateralTokenPriceFeedAddresses[0] = vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA");
            collateralTokenPriceFeedAddresses[1] = vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA");
        } else {
            // deploy mock ERC20 token for wETH and for wBTC
            vm.startBroadcast();
            mockWETH = new ERC20Mock();
            mockWBTC = new ERC20Mock();
            // deploy mock Chainlink AggregatorV3Interface for wETH pricefeed and for wBTC pricefeed
            mockEthPriceFeed = new MockAggregatorV3("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD");
            mockBtcPriceFeed = new MockAggregatorV3("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD");
            vm.stopBroadcast();
            // populate the 2 arrays with their respective addresses
            allowedCollateralTokenAddresses[0] = address(mockWETH);
            allowedCollateralTokenAddresses[1] = address(mockWBTC);
            collateralTokenPriceFeedAddresses[0] = address(mockEthPriceFeed);
            collateralTokenPriceFeedAddresses[1] = address(mockBtcPriceFeed);
        }
        */

        // deploy DSCEngine
        vm.startBroadcast();
        DSCEngine engine = new DSCEngine(
            allowedCollateralTokenAddresses,
            collateralTokenPriceFeedAddresses,
            dscToken,thresholdPercent);
        vm.stopBroadcast();
        // transfer ownership from initial owner to the DSCEngine
        vm.startBroadcast(DecentralizedStableCoin(dscToken).owner());
        DecentralizedStableCoin(dscToken).transferOwnership(address(engine));
        vm.stopBroadcast();
        return (engine,chainConfig);
    }
}