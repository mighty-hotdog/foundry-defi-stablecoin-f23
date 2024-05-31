// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";

contract DeployDSCEngineTest is Test {
    /* Errors */
    error DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(uint256 actualArrayLength);
    error DeployDSCEngineTest__IncorrectAllowedCollateralToken(address incorrectToken);
    error DeployDSCEngineTest__IncorrectPriceFeed(address incorrectPriceFeed);

    DecentralizedStableCoin public coin;
    DeployDecentralizedStableCoin public coinDeployer;
    DSCEngine public engine;
    DeployDSCEngine public engineDeployer;

    function setUp() external {
        // deploy coin (using coin deployer)
        coinDeployer = new DeployDecentralizedStableCoin();
        coin = coinDeployer.run();
        // deploy engine (using engine deployer)
        engineDeployer = new DeployDSCEngine();
        engine = engineDeployer.run(address(coin));
    }

    // test if engine deployer performed correctly:
    //  1. pass in zero for dscToken address
    function testDscTokenAddressCannotBeZero() external {
        DeployDSCEngine testEngineDeployer = new DeployDSCEngine();
        vm.expectRevert(DeployDSCEngine.DeployDSCEngine__DscTokenAddressCannotBeZero.selector);
        testEngineDeployer.run(address(0));
    }

    // Test of correct deployment (in Sepolia, Mainnet, or Anvil) is equivalent to testing the correct 
    // construction of the DSCEngine when deployed using DeployDSCEngine script.
    function testValidDscToken() external view {
        assert(engine.getDscTokenAddress() == address(coin));
    }
    function testThresholdPercentOutOfRange() external view {
        assert((engine.getThresholdLimitPercent() >= 1) && (engine.getThresholdLimitPercent() <= 99));
    }
    function testValidThresholdPercent() external view {
        assert(engine.getThresholdLimitPercent() == vm.envUint("THRESHOLD_PERCENT"));
    }

    //  2. deploy in SEPOLIA
    function testDeployInSepoliaWithCorrectAllowedCollateralTokensAndPriceFeeds() external view onlySepolia {
        console.log("Passed onlySepolia");
        (uint256 arrayLength,address[] memory allowedTokensArray) = engine.getAllowedCollateralTokensArray();
        if (arrayLength != 2) {
            revert DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(arrayLength);
        }
        for(uint256 i=0;i<arrayLength;i++) {
            address token = allowedTokensArray[i];
            if ((token != vm.envAddress("WETH_ADDRESS_SEPOLIA")) && 
                (token != vm.envAddress("WBTC_ADDRESS_SEPOLIA"))) {
                    revert DeployDSCEngineTest__IncorrectAllowedCollateralToken(token);
            }
            address priceFeed = engine.getPriceFeed(token);
            if ((priceFeed != vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA")) &&
                (priceFeed != vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_SEPOLIA"))) {
                    revert DeployDSCEngineTest__IncorrectPriceFeed(priceFeed);
            }
        }
    }
    //  3. deploy in MAINNET
    function testDeployInMainnetWithCorrectAllowedCollateralTokensAndPriceFeeds() external view onlyMainnet {
        console.log("Passed onlyMainnet");
        (uint256 arrayLength,address[] memory allowedTokensArray) = engine.getAllowedCollateralTokensArray();
        if (arrayLength != 2) {
            revert DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(arrayLength);
        }
        for(uint256 i=0;i<arrayLength;i++) {
            address token = allowedTokensArray[i];
            if ((token != vm.envAddress("WETH_ADDRESS_MAINNET")) && 
                (token != vm.envAddress("WBTC_ADDRESS_MAINNET"))) {
                    revert DeployDSCEngineTest__IncorrectAllowedCollateralToken(token);
            }
            address priceFeed = engine.getPriceFeed(token);
            if ((priceFeed != vm.envAddress("WETH_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET")) &&
                (priceFeed != vm.envAddress("WBTC_CHAINLINK_PRICE_FEED_ADDRESS_MAINNET"))) {
                    revert DeployDSCEngineTest__IncorrectPriceFeed(priceFeed);
            }
        }
    }
    //  4. deploy in Anvil
    function testDeployInAnvilWithCorrectAllowedCollateralTokensAndPriceFeeds() external view onlyAnvil {
        console.log("Passed onlyAnvil");
        (uint256 arrayLength,address[] memory allowedTokensArray) = engine.getAllowedCollateralTokensArray();
        if (arrayLength != 2) {
            revert DeployDSCEngineTest__IncorrectAllowedCollateralTokensArrayLength(arrayLength);
        }
        for(uint256 i=0;i<arrayLength;i++) {
            address token = allowedTokensArray[i];
            if ((token != address(engineDeployer.mockWETH())) && 
                (token != address(engineDeployer.mockWBTC()))) {
                    revert DeployDSCEngineTest__IncorrectAllowedCollateralToken(token);
            }
            address priceFeed = engine.getPriceFeed(token);
            if ((priceFeed != address(engineDeployer.mockEthPriceFeed())) &&
                (priceFeed != address(engineDeployer.mockBtcPriceFeed()))) {
                    revert DeployDSCEngineTest__IncorrectPriceFeed(priceFeed);
            }
        }
    }
    //  5. correctly transferred ownership of dscToken to engine
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