// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {ChainConfigurator} from "../../script/ChainConfigurator.s.sol";
//import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DecentralizedStableCoin public coin;
    DeployDecentralizedStableCoin public coinDeployer;
    DSCEngine public engine;
    DeployDSCEngine public engineDeployer;
    ChainConfigurator public config;
    address public USER;

    //////////////////////////////////////////////////////////////////
    // All events emitted by DSCEngine contract and to be tested for
    //////////////////////////////////////////////////////////////////
    //event CollateralDeposited(address indexed user,address indexed collateralTokenAddress,uint256 indexed amount);
    //event DSCMinted(address indexed toUser,uint256 indexed amount);
    //////////////////////////////////////////////////////////////////

    /* Modifiers */
    modifier skipIfNotOnAnvil() {
        if (block.chainid != vm.envUint("DEFAULT_ANVIL_CHAINID")) {
            return;
        }
        _;
    }

    /* Setup Function */
    function setUp() external {
        // deploy coin (using coin deployer)
        coinDeployer = new DeployDecentralizedStableCoin();
        coin = coinDeployer.run();
        // deploy engine (using engine deployer)
        engineDeployer = new DeployDSCEngine();
        (engine,config) = engineDeployer.run(address(coin));
        // prepare prank users with appropriate balances
        USER = makeAddr("user");
        /*
        // better to setup the test variables from within each test according to the 
        //  needs of each situation.
        (
            address weth,
            address wbtc,
            address wethPriceFeed,
            address wbtcPriceFeed
        ) = config.s_activeChainConfig();
        uint256 startBalance = vm.envUint("STARTING_BALANCE");
        ERC20Mock(weth).mint(USER,startBalance);
        ERC20Mock(wbtc).mint(USER,startBalance);
        ERC20Mock(weth).approve(address(engine),type(uint256).max);
        ERC20Mock(wbtc).approve(address(engine),type(uint256).max);
        */
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for constructor()
    ////////////////////////////////////////////////////////////////////
    function testDscTokenAddressCannotBeZero(uint256 thresholdLimit) external {
        address[] memory arrayOne;
        address[] memory arrayTwo;
        uint256[] memory arrayThree;
        address dscTokenAddress = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__DscTokenAddressCannotBeZero.selector);
        new DSCEngine(arrayOne,arrayTwo,arrayThree,dscTokenAddress,thresholdLimit);
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
    function testConstructorInputParamsMismatch(
        uint256 arrayOneLength,
        uint256 arrayTwoLength,
        uint256 arrayThreeLength,
        uint256 thresholdLimit) external 
    {
        arrayOneLength = bound(arrayOneLength,2,256);
        arrayTwoLength = bound(arrayTwoLength,2,256);
        arrayThreeLength = bound(arrayThreeLength,2,256);
        thresholdLimit = bound(thresholdLimit,1,99);
        address dscTokenAddress = makeAddr("mock token address");
        if (!((arrayOneLength == arrayTwoLength) &&
            (arrayOneLength == arrayThreeLength))) {
            address[] memory arrayOne = new address[](arrayOneLength);
            address[] memory arrayTwo = new address[](arrayTwoLength);
            uint256[] memory arrayThree = new uint256[](arrayThreeLength);
            console.log("arrayOne.length: ",arrayOne.length);
            console.log("arrayTwo.length: ",arrayTwo.length);
            console.log("arrayThree.length: ",arrayThree.length);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__ConstructorInputParamsMismatch(uint256,uint256,uint256)")),
                    arrayOne.length,
                    arrayTwo.length,
                    arrayThree.length));
            new DSCEngine(arrayOne,arrayTwo,arrayThree,dscTokenAddress,thresholdLimit);
        }
    }
    function testCollateralTokenAddressCannotBeZero(uint256 arrayLength,uint256 thresholdLimit) external {
        arrayLength = bound(arrayLength,2,256);
        thresholdLimit = bound(thresholdLimit,1,99);
        address dscTokenAddress = makeAddr("mock token address");
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        uint256[] memory arrayPrecision = new uint256[](arrayLength);
        arrayCollateral[0] = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokenAddressCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,arrayPrecision,dscTokenAddress,thresholdLimit);
    }
    function testPriceFeedAddressCannotBeZero(uint256 arrayLength,uint256 thresholdLimit) external {
        arrayLength = bound(arrayLength,2,256);
        thresholdLimit = bound(thresholdLimit,1,99);
        address dscTokenAddress = makeAddr("mock token address");
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        uint256[] memory arrayPrecision = new uint256[](arrayLength);
        arrayCollateral[0] = makeAddr("collateral");
        arrayPriceFeed[0] = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__PriceFeedAddressCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,arrayPrecision,dscTokenAddress,thresholdLimit);
    }
    function testPriceFeedPrecisionCannotBeZero(uint256 arrayLength,uint256 thresholdLimit) external {
        arrayLength = bound(arrayLength,2,256);
        thresholdLimit = bound(thresholdLimit,1,99);
        address dscTokenAddress = makeAddr("mock token address");
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        uint256[] memory arrayPrecision = new uint256[](arrayLength);
        arrayCollateral[0] = makeAddr("collateral");
        arrayPriceFeed[0] = makeAddr("price feed");
        arrayPrecision[0] = 0;
        vm.expectRevert(DSCEngine.DSCEngine__PriceFeedPrecisionCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,arrayPrecision,dscTokenAddress,thresholdLimit);
    }
    // Skipped. This is more of a deployment/integration test.
    // It is already performed in the DeployDSCEngineTest test script under:
    //  1. testDeployInSepoliaWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //  2. testDeployInMainnetWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //  3. testDeployInAnvilWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //function testCorrectAllowedCollateralTokensAndPriceFeeds() external {}

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getAllDeposits()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getDepositAmount()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getDepositsValueInUsd()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getMints()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getMintsValueInUsd()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getTokensHeld()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getTokensHeldValueInUsd()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for depositCollateralMintDSC()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for depositCollateral()
    ////////////////////////////////////////////////////////////////////
    function testDepositZeroAmount() external {
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        for(uint256 i=0;i<arraySize;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            vm.prank(USER);
            vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
            engine.depositCollateral(token,0);
        }
    }
    function testDepositTokenWithZeroAddress(uint256 randomDepositAmount) external {
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokenAddressCannotBeZero.selector);
        engine.depositCollateral(address(0),randomDepositAmount);
    }
    function testDepositNonAllowedTokens(address randomTokenAddress,uint256 randomDepositAmount) external {
        vm.assume(randomTokenAddress != address(0));
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<arraySize;i++) {
            if (randomTokenAddress == engine.getAllowedCollateralTokens(i)) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            // if deposit non-allowed token, revert
            vm.prank(USER);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                    randomTokenAddress));
            engine.depositCollateral(randomTokenAddress,randomDepositAmount);
        }
    }
    function testDepositAllowedTokens(uint256 randomDepositAmount) external skipIfNotOnAnvil {
        // this test just checks that given the inputs depositCollateral() runs with no reverts

        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        for(uint256 i=0;i<arraySize;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(token).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(token).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.prank(USER);
            engine.depositCollateral(token,randomDepositAmount);
        }
    }
    function testDepositStateCorrectlyUpdated(uint256 randomDepositAmount) external skipIfNotOnAnvil {
        // here we check that:
        //  1. engine deposit records are correct
        //  2. user balance is correct
        //  3. engine balance is correct

        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        for(uint256 i=0;i<arraySize;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(token).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(token).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.prank(USER);
            engine.depositCollateral(token,randomDepositAmount);
            // do the check
            vm.prank(USER);
            uint256 depositHeld = engine.getDepositAmount(token);
            assert(
                // check that user deposit records on engine are correct
                (depositHeld == randomDepositAmount) &&
                // check that user token balance is correct
                (ERC20Mock(token).balanceOf(USER) == 0) &&
                // check that engine token balance is correct
                (ERC20Mock(token).balanceOf(address(engine)) == randomDepositAmount)
            );
        }
    }
    function testEmitCollateralDeposited(uint256 randomDepositAmount) external skipIfNotOnAnvil {
        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        for(uint256 i=0;i<arraySize;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(token).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(token).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.expectEmit(true,true,true,false,address(engine));
            emit DSCEngine.CollateralDeposited(USER,token,randomDepositAmount);
            vm.prank(USER);
            engine.depositCollateral(token,randomDepositAmount);
        }
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for mintDSC()
    ////////////////////////////////////////////////////////////////////
    function testMintZeroAmount() external {
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.mintDSC(0);
    }
    function testMintOutsideLimit(
        uint256 requestedMintAmount,
        uint256 valueOfDepositsHeld,
        uint256 wethDepositAmount,
        uint256 wbtcDepositAmount,
        uint256 valueOfMintsAlreadyHeld
        ) external skipIfNotOnAnvil {
        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        
        // how to test mintDSC()
        //  1. set arbitrary max deposit limit = 1 billion USD
        //  2. bound valueOfDepositsHeld by max deposit limit
        //  3. bound wethDepositAmount by max deposit limit
        //  4. bound wbtcDepositAmount by max deposit limit for a particular random wethDepositAmount value
        //  5. deposit random weth and wbtc amounts via depositCollateral()
        //  6. calc numerator, ie: valueOfDepositsHeld * thresholdLimit
        //  7. bound valueOfMintsAlreadyHeld by numerator / FRACTION_REMOVAL_MULTIPLIER
        //  8. mint valueOfMintsAlreadyHeld via mintDSC()
        //  9. bound requestedMintAmount for a particular random valueOfMintsAlreadyHeld value such that mint
        //      request is **OUTSIDE** limit
        //  10. perform the test by calling mintDSC() for random requestedMintAmount and checking for revert

        // get token address for weth and wbtc for use later
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        //  1. set arbitrary max deposit limit = 1mil USD
        uint256 maxDepositValueInUSD = 1000000000;  // 1 billion USD
        //  2. bound valueOfDepositsHeld by max deposit limit
        valueOfDepositsHeld = bound(valueOfDepositsHeld,1,maxDepositValueInUSD);
        // get mock price of weth from .env
        uint256 wethPriceInUSD = 
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD") / 
            10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD"));
        //  3. bound wethDepositAmount by max deposit limit
        wethDepositAmount = bound(wethDepositAmount,0,maxDepositValueInUSD/wethPriceInUSD);
        // get mock price of wbtc from .env
        uint256 wbtcPriceInUSD = 
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD") / 
            10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD"));
        //  4. bound wbtcDepositAmount by max deposit limit for a particular random wethDepositAmount value
        wbtcDepositAmount = bound(
            wbtcDepositAmount,
            0,
            (maxDepositValueInUSD - engine.exposeconvertToUsd(weth,wethDepositAmount)) / wbtcPriceInUSD);
        //  5. deposit random weth and wbtc amounts via depositCollateral()
        if (wethDepositAmount > 0) {
            ERC20Mock(weth).mint(USER,wethDepositAmount);
            vm.startPrank(USER);
            ERC20Mock(weth).approve(address(engine),wethDepositAmount);
            engine.depositCollateral(weth,wethDepositAmount);
            vm.stopPrank();
        }
        if (wbtcDepositAmount > 0) {
            ERC20Mock(wbtc).mint(USER,wbtcDepositAmount);
            vm.startPrank(USER);
            ERC20Mock(wbtc).approve(address(engine),wbtcDepositAmount);
            engine.depositCollateral(wbtc,wbtcDepositAmount);
            vm.stopPrank();
        }
        //  6. calc numerator, ie: valueOfDepositsHeld * thresholdLimit
        uint256 numerator = engine.exposegetValueOfDepositsInUsd(USER) * engine.getThresholdLimitPercent();
        //  7. bound valueOfMintsAlreadyHeld by numerator / FRACTION_REMOVAL_MULTIPLIER
        valueOfMintsAlreadyHeld = bound(valueOfMintsAlreadyHeld,0,numerator/engine.getFractionRemovalMultiplier());
        //  8. mint valueOfMintsAlreadyHeld via mintDSC()
        if (valueOfMintsAlreadyHeld > 0) {
            vm.prank(USER);
            engine.mintDSC(valueOfMintsAlreadyHeld);
        }
        //  9. bound requestedMintAmount for a particular random valueOfMintsAlreadyHeld value such that mint
        //      request is **OUTSIDE** limit
        uint256 maxSafeMintAmount = (numerator / engine.getFractionRemovalMultiplier()) - 
            engine.exposegetValueOfDscMintsInUsd(USER);
        requestedMintAmount = bound(
            requestedMintAmount,
            maxSafeMintAmount+1,
            maxDepositValueInUSD);
        //  10. perform the test by calling mintDSC() for random requestedMintAmount and checking for revert
        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedMintAmountBreachesUserMintLimit(address,uint256,uint256)")),
                USER,
                requestedMintAmount,
                maxSafeMintAmount));
        engine.mintDSC(requestedMintAmount);
    }

    // Skipped. This test is already implicitly performed in testMintStateCorrectlyUpdated().
    //function testMintWithinLimit() external {}

    function testMintStateCorrectlyUpdated(
        uint256 requestedMintAmount,
        uint256 valueOfDepositsHeld,
        uint256 wethDepositAmount,
        uint256 wbtcDepositAmount,
        uint256 valueOfMintsAlreadyHeld
        ) external skipIfNotOnAnvil {
        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        
        // how to test mintDSC()
        //  1. set arbitrary max deposit limit = 1mil USD
        //  2. bound valueOfDepositsHeld by max deposit limit
        //  3. bound wethDepositAmount by max deposit limit
        //  4. bound wbtcDepositAmount by max deposit limit for a particular random wethDepositAmount value
        //  5. deposit random weth and wbtc amounts via depositCollateral()
        //  6. calc numerator, ie: valueOfDepositsHeld * thresholdLimit
        //  7. bound valueOfMintsAlreadyHeld by numerator / FRACTION_REMOVAL_MULTIPLIER
        //  8. mint valueOfMintsAlreadyHeld via mintDSC()
        //  9. bound requestedMintAmount for a particular random valueOfMintsAlreadyHeld value such that mint
        //      request is **WITHIN** limit
        //  10. perform the test by calling mintDSC() for random requestedMintAmount
        //  11. check that:
        //      a. expected event emitted
        //      b. minted DSC balance held by user is correct
        //      c. total supply of DSC minted is correct

        // get token address for weth and wbtc for use later
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        //  1. set arbitrary max deposit limit = 1mil USD
        uint256 maxDepositValueInUSD = 1000000;
        //  2. bound valueOfDepositsHeld by max deposit limit
        valueOfDepositsHeld = bound(valueOfDepositsHeld,1,maxDepositValueInUSD);
        // get mock price of weth from .env
        uint256 wethPriceInUSD = 
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD") / 
            10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD"));
        //  3. bound wethDepositAmount by max deposit limit
        wethDepositAmount = bound(wethDepositAmount,0,maxDepositValueInUSD/wethPriceInUSD);
        // get mock price of wbtc from .env
        uint256 wbtcPriceInUSD = 
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD") / 
            10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD"));
        //  4. bound wbtcDepositAmount by max deposit limit for a particular random wethDepositAmount value
        wbtcDepositAmount = bound(
            wbtcDepositAmount,
            0,
            (maxDepositValueInUSD - engine.exposeconvertToUsd(weth,wethDepositAmount)) / wbtcPriceInUSD);
        //  5. deposit random weth and wbtc amounts via depositCollateral()
        if (wethDepositAmount > 0) {
            ERC20Mock(weth).mint(USER,wethDepositAmount);
            vm.startPrank(USER);
            ERC20Mock(weth).approve(address(engine),wethDepositAmount);
            engine.depositCollateral(weth,wethDepositAmount);
            vm.stopPrank();
        }
        if (wbtcDepositAmount > 0) {
            ERC20Mock(wbtc).mint(USER,wbtcDepositAmount);
            vm.startPrank(USER);
            ERC20Mock(wbtc).approve(address(engine),wbtcDepositAmount);
            engine.depositCollateral(wbtc,wbtcDepositAmount);
            vm.stopPrank();
        }
        //  6. calc numerator, ie: valueOfDepositsHeld * thresholdLimit
        uint256 numerator = engine.exposegetValueOfDepositsInUsd(USER) * engine.getThresholdLimitPercent();
        //  7. bound valueOfMintsAlreadyHeld by numerator / FRACTION_REMOVAL_MULTIPLIER
        valueOfMintsAlreadyHeld = bound(valueOfMintsAlreadyHeld,0,numerator/engine.getFractionRemovalMultiplier());
        //  8. mint valueOfMintsAlreadyHeld via mintDSC()
        if (valueOfMintsAlreadyHeld > 0) {
            vm.prank(USER);
            engine.mintDSC(valueOfMintsAlreadyHeld);
        }
        //  9. bound requestedMintAmount for a particular random valueOfMintsAlreadyHeld value such that mint
        //      request is **WITHIN** limit
        requestedMintAmount = bound(
            requestedMintAmount,
            0,
            (numerator/engine.getFractionRemovalMultiplier())-engine.exposegetValueOfDscMintsInUsd(USER));
        //  10. perform the test by calling mintDSC() for random requestedMintAmount
        if (requestedMintAmount > 0) {
            //  11. check that:
            //      a. expected event emitted
            vm.expectEmit(true,true,false,false,address(engine));
            emit DSCEngine.DSCMinted(USER,requestedMintAmount);
            vm.prank(USER);
            engine.mintDSC(requestedMintAmount);

            vm.prank(USER);
            uint256 mintHeld = engine.getMints();
            assert(
                //  b. minted DSC balance held by user is correct
                (mintHeld == coin.totalSupply()) &&
                //  c. total supply of DSC minted is correct
                (coin.totalSupply() == valueOfMintsAlreadyHeld + requestedMintAmount)
            );
        }
    }

    // Skipped. This test is already performed in testMintStateCorrectlyUpdated().
    //function testEmitDSCMinted() external {}

    ////////////////////////////////////////////////////////////////////
    // Unit tests for redeemCollateralBurnDSC()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for redeemCollateral()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for burnDSC()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for liquidate()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertFromTo()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertFromUsd()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertToUsd()
    ////////////////////////////////////////////////////////////////////
    function testConvertWETH(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,100);
        (address weth,,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wETH converted to ",engine.exposeconvertToUsd(weth,randomAmount)," USD");
    }
    function testConvertWBTC(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,100);
        (,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wBTC converted to ",engine.exposeconvertToUsd(wbtc,randomAmount)," USD");
    }
    function testConvertWETHOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,100);
        (address weth,,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertToUsd(weth,randomAmount);
        console.log(randomAmount," wETH converted to ",returnValue," USD");
        assertEq(
            returnValue,
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD") * 
                randomAmount / 
                10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD")));
    }
    function testConvertWBTCOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,100);
        (,address wbtc,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertToUsd(wbtc,randomAmount);
        console.log(randomAmount," wBTC converted to ",returnValue," USD");
        assertEq(
            returnValue,
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD") * 
                randomAmount / 
                10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD")));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getValueOfDepositsInUsd()
    ////////////////////////////////////////////////////////////////////
    function testValueOfDepositsIsCorrect(uint256 randomDepositAmount) external skipIfNotOnAnvil {
        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        randomDepositAmount = bound(randomDepositAmount,1,100);
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        for(uint256 i=0;i<arraySize;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(token).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(token).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.prank(USER);
            engine.depositCollateral(token,randomDepositAmount);
            console.log("Deposit #",i+1,": ",randomDepositAmount);
        }
        uint256 returnValue = engine.exposegetValueOfDepositsInUsd(USER);
        console.log("Value of Deposits: ",returnValue,"USD");
        assertEq(
            returnValue,
            (
                (vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD") * 
                    randomDepositAmount / 
                    10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD"))) + 
                (vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD") * 
                    randomDepositAmount / 
                    10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD")))
            )
        );
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getValueOfDscMintsInUsd()
    // Skipped. This function just returns contents of 
    //  an internal variable.
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for _redeemCollateral()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for _burnDSC()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getFractionRemovalMultiplier()
    // Skipped. This function just returns a constant.
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getDscTokenAddress()
    // Skipped. This function just returns an immutable.
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getThresholdLimitPercent()
    // Skipped. This function just returns an immutable.
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getAllowedCollateralTokensArrayLength()
    // Skipped. This function just returns array length of
    //  an internal array.
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getAllowedCollateralTokens()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getPriceFeed()
    ////////////////////////////////////////////////////////////////////
}