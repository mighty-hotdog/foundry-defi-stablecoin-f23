// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {ChainConfigurator} from "../../script/ChainConfigurator.s.sol";

contract DeployDSCEngineTest is Test {
    /* Errors */
    error DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(uint256 actualArrayLength);
    error DeployDSCEngineTest__IncorrectAllowedCollateralToken(address incorrectToken);
    error DeployDSCEngineTest__IncorrectPriceFeed(address incorrectPriceFeed);

    DecentralizedStableCoin public coin;
    DeployDecentralizedStableCoin public coinDeployer;
    DSCEngine public engine;
    DeployDSCEngine public engineDeployer;
    ChainConfigurator public config;

    function setUp() external {
        // deploy coin (using coin deployer)
        coinDeployer = new DeployDecentralizedStableCoin();
        coin = coinDeployer.run();
        // deploy engine (using engine deployer)
        engineDeployer = new DeployDSCEngine();
        (engine,config) = engineDeployer.run(address(coin));
    }

    // Test of correct deployment (in Sepolia, Mainnet, or Anvil) is equivalent to testing the correct 
    // construction of the DSCEngine when deployed using DeployDSCEngine script.
    function testDscTokenAddressCannotBeZero() external {
        DeployDSCEngine testEngineDeployer = new DeployDSCEngine();
        vm.expectRevert(DeployDSCEngine.DeployDSCEngine__DscTokenAddressCannotBeZero.selector);
        testEngineDeployer.run(address(0));
    }
    function testValidDscToken() external view {
        assert(engine.i_dscToken() == address(coin));
    }
    function testThresholdPercentWithinRange() external view {
        assert((engine.i_thresholdLimitPercent() >= 1) && (engine.i_thresholdLimitPercent() <= 99));
    }
    function testValidThresholdPercent() external view {
        assert(engine.i_thresholdLimitPercent() == vm.envUint("THRESHOLD_PERCENT"));
    }
    function testDeployInSepoliaWithCorrectAllowedCollateralTokensAndPriceFeeds() external view onlySepolia {
        console.log("Passed onlySepolia");
        uint256 arrayLength = engine.getAllowedCollateralTokensArrayLength();
        if (arrayLength != 2) {
            revert DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(arrayLength);
        }
        for(uint256 i=0;i<arrayLength;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            if ((token != vm.envAddress("WETH_ADDRESS_SEPOLIA")) && 
                (token != vm.envAddress("WBTC_ADDRESS_SEPOLIA"))) {
                    revert DeployDSCEngineTest__IncorrectAllowedCollateralToken(token);
            }
            (address priceFeed,) = engine.getPriceFeed(token);
            if ((priceFeed != vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA")) &&
                (priceFeed != vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA"))) {
                    revert DeployDSCEngineTest__IncorrectPriceFeed(priceFeed);
            }
        }
    }
    function testDeployInMainnetWithCorrectAllowedCollateralTokensAndPriceFeeds() external view onlyMainnet {
        console.log("Passed onlyMainnet");
        uint256 arrayLength = engine.getAllowedCollateralTokensArrayLength();
        if (arrayLength != 2) {
            revert DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(arrayLength);
        }
        for(uint256 i=0;i<arrayLength;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            if ((token != vm.envAddress("WETH_ADDRESS_MAINNET")) && 
                (token != vm.envAddress("WBTC_ADDRESS_MAINNET"))) {
                    revert DeployDSCEngineTest__IncorrectAllowedCollateralToken(token);
            }
            (address priceFeed,) = engine.getPriceFeed(token);
            if ((priceFeed != vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET")) &&
                (priceFeed != vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET"))) {
                    revert DeployDSCEngineTest__IncorrectPriceFeed(priceFeed);
            }
        }
    }
    function testDeployInAnvilWithCorrectAllowedCollateralTokensAndPriceFeeds() external view onlyAnvil {
        console.log("Passed onlyAnvil");
        uint256 arrayLength = engine.getAllowedCollateralTokensArrayLength();
        if (arrayLength != 2) {
            revert DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(arrayLength);
        }
        for(uint256 i=0;i<arrayLength;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            (
                address mockWETH,
                address mockWBTC,
                address mockWethPriceFeed,
                address mockWbtcPriceFeed,,
            ) = config.s_activeChainConfig();
            if ((token != mockWETH) && 
                (token != mockWBTC)) {
                    revert DeployDSCEngineTest__IncorrectAllowedCollateralToken(token);
            }
            (address priceFeed,) = engine.getPriceFeed(token);
            if ((priceFeed != mockWethPriceFeed) &&
                (priceFeed != mockWbtcPriceFeed)) {
                    revert DeployDSCEngineTest__IncorrectPriceFeed(priceFeed);
            }
        }
    }
    function testTransferOwnershipOfDscTokenToDSCEngine() external view {
        assert(coin.owner() == address(engine));
    }

    modifier onlySepolia() {
        if (block.chainid != vm.envUint("ETH_SEPOLIA_CHAINID")) {
            return;
        }
        _;
    }

    modifier onlyMainnet() {
        if (block.chainid != vm.envUint("ETH_MAINNET_CHAINID")) {
            return;
        }
        _;
    }

    modifier onlyAnvil() {
        if (block.chainid != vm.envUint("DEFAULT_ANVIL_CHAINID")) {
            return;
        }
        _;
    }
}