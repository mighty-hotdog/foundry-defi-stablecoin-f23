// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";

contract DSCEngineTest is Test {
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

    ////////////////////////////////////////////////////////////////////
    // Unit tests for constructor()
    ////////////////////////////////////////////////////////////////////
    function testDscTokenAddressCannotBeZero(uint256 thresholdLimit) external {
        address[] memory arrayOne;
        address[] memory arrayTwo;
        address dscTokenAddress = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__DscTokenAddressCannotBeZero.selector);
        new DSCEngine(arrayOne,arrayTwo,dscTokenAddress,thresholdLimit);
    }
    function testValidDscToken() external view {
        assert(engine.getDscTokenAddress() == address(coin));
    }
    function testThresholdPercentWithinRange() external view {
        assert((engine.getThresholdLimitPercent() >= 1) && (engine.getThresholdLimitPercent() <= 99));
    }
    function testValidThresholdPercent() external view {
        assert(engine.getThresholdLimitPercent() == vm.envUint("THRESHOLD_PERCENT"));
    }
    function testConstructorInputParamsMismatch(uint256 arrayOneLength,uint256 arrayTwoLength,uint256 thresholdLimit) external {
        arrayOneLength = bound(arrayOneLength,2,256);
        arrayTwoLength = bound(arrayTwoLength,2,256);
        thresholdLimit = bound(thresholdLimit,1,99);
        address dscTokenAddress = makeAddr("mock token address");
        if (arrayOneLength != arrayTwoLength) {
            address[] memory arrayOne = new address[](arrayOneLength);
            address[] memory arrayTwo = new address[](arrayTwoLength);
            console.log("arrayOne.length: ",arrayOne.length);
            console.log("arrayTwo.length: ",arrayTwo.length);
            vm.expectRevert();
            new DSCEngine(arrayOne,arrayTwo,dscTokenAddress,thresholdLimit);
        }
    }
    function testCollateralTokenAddressCannotBeZero(uint256 arrayLength,uint256 thresholdLimit) external {
        arrayLength = bound(arrayLength,2,256);
        thresholdLimit = bound(thresholdLimit,1,99);
        address dscTokenAddress = makeAddr("mock token address");
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        arrayCollateral[0] = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokenAddressCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,dscTokenAddress,thresholdLimit);
    }
    function testPriceFeedAddressCannotBeZero(uint256 arrayLength,uint256 thresholdLimit) external {
        arrayLength = bound(arrayLength,2,256);
        thresholdLimit = bound(thresholdLimit,1,99);
        address dscTokenAddress = makeAddr("mock token address");
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        arrayCollateral[0] = makeAddr("collateral");
        arrayPriceFeed[0] = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__PriceFeedAddressCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,dscTokenAddress,thresholdLimit);
    }
    // This test is considered more a deployment/integration test.
    // It is performed in the DeployDSCEngineTest test script under:
    //  1. testDeployInSepoliaWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //  2. testDeployInMainnetWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //  3. testDeployInAnvilWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //function testCorrectAllowedCollateralTokensAndPriceFeeds() external {}

    ////////////////////////////////////////////////////////////////////
    // Unit tests for depositCollateral()
    ////////////////////////////////////////////////////////////////////
    function testDepositAllowedTokens() external {}
    function testDepositNonAllowedTokens() external {}
    function testAmountCannotBeZero() external {}
    function testDepositStateCorrectlyUpdated() external {}
    function testEmitCollateralDeposited() external {}
    function testDepositTransferSuccessful() external {}

    ////////////////////////////////////////////////////////////////////
    // Unit tests for mintDSC()
    ////////////////////////////////////////////////////////////////////
}