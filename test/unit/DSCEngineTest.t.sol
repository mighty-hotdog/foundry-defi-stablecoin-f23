// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {ChainConfigurator} from "../../script/ChainConfigurator.s.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

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
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
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
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
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
        //  1. set arbitrary max deposit limit = 1 billion USD
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
        //  1. set arbitrary max deposit limit = 1 billion USD
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
    function testBurnZeroAmount() external {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.burnDSC(0);
        vm.stopPrank();
    }
    function testBurnInsufficientBalance(
        uint256 burnAmount,
        uint256 amountHeld
        ) external 
    {
        vm.assume(amountHeld != 0);
        vm.assume(burnAmount > amountHeld);
        vm.prank(address(engine));
        coin.mint(USER,amountHeld);
        assertEq(
            coin.balanceOf(USER),
            amountHeld);
        assertGt(burnAmount,amountHeld);
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedBurnAmountExceedsBalance(address,uint256,uint256)")),
                USER,
                amountHeld,
                burnAmount));
        engine.burnDSC(burnAmount);
        vm.stopPrank();
    }
    function testBurnStateCorrectlyUpdatedWeth(
        uint256 burnAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        (address depositToken,,,,,) = config.s_activeChainConfig();
        BurnStateCorrectlyUpdated(
            burnAmount,
            depositToken,
            depositAmount,
            mintAmount);
    }
    function testBurnStateCorrectlyUpdatedWbtc(
        uint256 burnAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        (,address depositToken,,,,) = config.s_activeChainConfig();
        BurnStateCorrectlyUpdated(
            burnAmount,
            depositToken,
            depositAmount,
            mintAmount);
    }
    function BurnStateCorrectlyUpdated(
        uint256 burnAmount,
        address depositToken,
        uint256 depositAmount,
        uint256 mintAmount
        ) internal
    {
        // setup
        //  1. mint collateral tokens for USER to deposit
        //  2. USER deposits collaterals and mints DSC (aka take on debt)
        uint256 maxDepositAmount = 1e9;    // 1 billion collateral tokens, arbitrary limit to avoid math overflow
        depositAmount = bound(depositAmount,1,maxDepositAmount);
        uint256 maxMintAmount = engine.exposeconvertToUsd(depositToken,depositAmount) 
            * engine.getThresholdLimitPercent() 
            / engine.getFractionRemovalMultiplier();
        mintAmount = bound(mintAmount,1,maxMintAmount);
        burnAmount = bound(burnAmount,1,mintAmount);
        ERC20Mock(depositToken).mint(USER,depositAmount);
        vm.startPrank(USER);
        ERC20Mock(depositToken).approve(address(engine),depositAmount);
        engine.depositCollateral(depositToken,depositAmount);
        engine.mintDSC(mintAmount);
        vm.stopPrank();

        // start the burn and do the tests
        //  1. check for emit
        //  2. check that USER DSC mint debt is drawn down by burn amount
        //  3. check that USER DSC token balance is drawn down by burn amount
        //  4. check that DSC token total supply is drawn down by burn amount
        uint256 dscTotalSupplyBeforeBurn = coin.totalSupply();
        vm.prank(USER);
        coin.approve(address(engine),burnAmount);
        // check for emit
        vm.startPrank(USER);
        vm.expectEmit(true,true,false,false,address(engine));
        emit DSCEngine.DSCBurned(USER,burnAmount);
        // start the burn!!
        engine.burnDSC(burnAmount);
        vm.stopPrank();
        // check that USER DSC mint debt is drawn down by burn amount
        vm.startPrank(USER);
        assertEq(engine.getMints(),mintAmount - burnAmount);
        vm.stopPrank();
        // check that USER DSC token balance is drawn down by burn amount
        assertEq(coin.balanceOf(USER),mintAmount - burnAmount);
        // check that DSC token total supply is drawn down by burn amount
        assertEq(coin.totalSupply(),dscTotalSupplyBeforeBurn - burnAmount);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for liquidate()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertFromTo()
    ////////////////////////////////////////////////////////////////////
    function testConvertFromZero(uint256 randomAmount) external {
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        engine.exposeconvertFromTo(address(0),randomAmount,makeAddr("toToken"));
    }
    function testConvertToZero(uint256 randomAmount) external {
        address allowedToken = engine.getAllowedCollateralTokens(0);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        engine.exposeconvertFromTo(allowedToken,randomAmount,address(0));
    }
    function testConvertFromZeroToZero(uint256 randomAmount) external {
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        engine.exposeconvertFromTo(address(0),randomAmount,address(0));
    }
    function testConvertFromNonAllowed(uint256 randomAmount,address randomToken) external {
        vm.assume(randomToken != address(0));
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<engine.getAllowedCollateralTokensArrayLength();i++) {
            if (randomToken == engine.getAllowedCollateralTokens(i)) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            address allowedToken = engine.getAllowedCollateralTokens(0);
            vm.prank(USER);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                    randomToken));
            engine.exposeconvertFromTo(
                randomToken,
                randomAmount,
                allowedToken);
        }
    }
    function testConvertToNonAllowed(uint256 randomAmount,address randomToken) external {
        vm.assume(randomToken != address(0));
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<engine.getAllowedCollateralTokensArrayLength();i++) {
            if (randomToken == engine.getAllowedCollateralTokens(i)) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            address allowedToken = engine.getAllowedCollateralTokens(0);
            vm.prank(USER);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                    randomToken));
            engine.exposeconvertFromTo(
                allowedToken,
                randomAmount,
                randomToken);
        }
    }
    function testConvertFromNonAllowedToNonAllowed(uint256 randomAmount,address randomTokenA,address randomTokenB) external {
        vm.assume(randomTokenA != address(0));
        vm.assume(randomTokenB != address(0));
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<engine.getAllowedCollateralTokensArrayLength();i++) {
            address token = engine.getAllowedCollateralTokens(i);
            if ((randomTokenA == token) || (randomTokenB == token)) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            vm.prank(USER);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                    randomTokenA));
            engine.exposeconvertFromTo(
                randomTokenA,
                randomAmount,
                randomTokenB);
        }
    }
    function testConvertWethToWbtc(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wETH converted to ",engine.exposeconvertFromTo(weth,randomAmount,wbtc)," wBTC");
    }
    function testConvertWbtcToWeth(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wBTC converted to ",engine.exposeconvertFromTo(wbtc,randomAmount,weth)," wETH");
    }
    function testConvertWethToWbtcOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertFromTo(weth,randomAmount,wbtc);
        console.log(randomAmount," wETH converted to ",returnValue," wBTC");
        // wethToUsd = randomAmount * wethPriceFeedAnswer / precision
        // wbtcPrice = wbtcPriceFeedAnswer / precision
        // wethToWbtc = wethToUsd / wbtcPrice = randomAmount * wethPriceFeedAnswer / wbtcPriceFeedAnswer
        uint256 mockWethPriceFeedAnswer = vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD");
        uint256 mockWbtcPriceFeedAnswer = vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD");
        assertEq(
            returnValue,
            randomAmount * mockWethPriceFeedAnswer / mockWbtcPriceFeedAnswer);
    }
    function testConvertWbtcToWethOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertFromTo(wbtc,randomAmount,weth);
        console.log(randomAmount," wBTC converted to ",returnValue," wETH");
        // wbtcToWeth = wbtcToUsd / wethPrice = randomAmount * wbtcPriceFeedAnswer / wethPriceFeedAnswer
        uint256 mockWethPriceFeedAnswer = vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD");
        uint256 mockWbtcPriceFeedAnswer = vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD");
        assertEq(
            returnValue,
            randomAmount * mockWbtcPriceFeedAnswer / mockWethPriceFeedAnswer);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertFromUsd()
    ////////////////////////////////////////////////////////////////////
    function testConvertToZeroTokenAddress(uint256 randomAmount) external {
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        engine.exposeconvertFromUsd(randomAmount,address(0));
    }
    function testConvertToNonAllowedTokens(uint256 randomAmount,address randomToken) external {
        vm.assume(randomToken != address(0));
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<engine.getAllowedCollateralTokensArrayLength();i++) {
            if (randomToken == engine.getAllowedCollateralTokens(i)) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            vm.prank(USER);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                    randomToken));
            engine.exposeconvertFromUsd(randomAmount,randomToken);
        }
    }
    function testConvertToWETH(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e9);   // 1e9 == 1 billion USD, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," USD converted to ",engine.exposeconvertFromUsd(randomAmount,weth)," wEth");
    }
    function testConvertToWBTC(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e9);   // 1e9 == 1 billion USD, arbitrary limit to prevent calc overflow
        (,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," USD converted to ",engine.exposeconvertFromUsd(randomAmount,wbtc)," wBTC");
    }
    function testConvertToWETHOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,1e9);   // 1e9 == 1 billion USD, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertFromUsd(randomAmount,weth);
        console.log(randomAmount," USD converted to ",returnValue," wETH");
        assertEq(
            returnValue,
            randomAmount * (10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD")))
                / vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD"));
    }
    function testConvertToWBTCOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,1e9);   // 1e9 == 1 billion USD, arbitrary limit to prevent calc overflow
        (,address wbtc,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertFromUsd(randomAmount,wbtc);
        console.log(randomAmount," USD converted to ",returnValue," wBTC");
        assertEq(
            returnValue,
            randomAmount * (10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD")))
                / vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD"));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertToUsd()
    ////////////////////////////////////////////////////////////////////
    function testConvertFromZeroTokenAddress(uint256 randomAmount) external {
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        engine.exposeconvertToUsd(address(0),randomAmount);
    }
    function testConvertFromNonAllowedTokens(uint256 randomAmount,address randomToken) external {
        vm.assume(randomToken != address(0));
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<engine.getAllowedCollateralTokensArrayLength();i++) {
            if (randomToken == engine.getAllowedCollateralTokens(i)) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            vm.prank(USER);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                    randomToken));
            engine.exposeconvertToUsd(randomToken,randomAmount);
        }
    }
    function testConvertFromWETH(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wETH converted to ",engine.exposeconvertToUsd(weth,randomAmount)," USD");
    }
    function testConvertFromWBTC(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wBTC converted to ",engine.exposeconvertToUsd(wbtc,randomAmount)," USD");
    }
    function testConvertFromWETHOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertToUsd(weth,randomAmount);
        console.log(randomAmount," wETH converted to ",returnValue," USD");
        assertEq(
            returnValue,
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD") * randomAmount 
                / (10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD"))));
    }
    function testConvertFromWBTCOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (,address wbtc,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertToUsd(wbtc,randomAmount);
        console.log(randomAmount," wBTC converted to ",returnValue," USD");
        assertEq(
            returnValue,
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD") * randomAmount 
                / (10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD"))));
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
        // perform the test:
        //  check that value of deposits is correct based on the deposits made
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
    function test_redeemFromZeroAddress(address to,address token,uint256 amount) external {
        vm.expectRevert(DSCEngine.DSCEngine__UserCannotBeZero.selector);
        engine.expose_redeemCollateral(address(0),to,token,amount);
    }
    function test_redeemToZeroAddress(address from,address token,uint256 amount) external {
        vm.assume(from != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__UserCannotBeZero.selector);
        engine.expose_redeemCollateral(from,address(0),token,amount);
    }
    function test_redeemFromZeroAddressToZeroAddress(address token,uint256 amount) external {
        vm.expectRevert(DSCEngine.DSCEngine__UserCannotBeZero.selector);
        engine.expose_redeemCollateral(address(0),address(0),token,amount);
    }
    function test_redeemZeroAmount(address from,address to,address token) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(token != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.expose_redeemCollateral(from,to,token,0);
    }
    function test_redeemZeroTokenAddress(address from,address to,uint256 amount) external {
        vm.assume(amount != 0);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        engine.expose_redeemCollateral(from,to,address(0),amount);
    }
    function test_redeemNonAllowedToken(address from,address to,address token,uint256 amount) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(amount != 0);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        vm.assume(token != weth);
        vm.assume(token != wbtc);
        vm.assume(token != address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                token));
        engine.expose_redeemCollateral(from,to,token,amount);
    }
    function test_redeemInsufficientBalanceWeth(
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount
        ) external skipIfNotOnAnvil 
    {
        (address token,,,,,) = config.s_activeChainConfig();
        _redeemInsufficientBalance(
            from,
            to,
            token,
            redeemAmount,
            depositAmount);
    }
    function test_redeemInsufficientBalanceWbtc(
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount
        ) external skipIfNotOnAnvil 
    {
        (,address token,,,,) = config.s_activeChainConfig();
        _redeemInsufficientBalance(
            from,
            to,
            token,
            redeemAmount,
            depositAmount);
    }
    function _redeemInsufficientBalance(
        address from,
        address to,
        address token,
        uint256 redeemAmount,
        uint256 depositAmount
        ) internal
    {
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        vm.assume(redeemAmount > depositAmount);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        // mint collateral token to fromuser
        ERC20Mock(token).mint(from,depositAmount);
        // fromuser approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(from);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // fromuser deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedRedeemAmountExceedsBalance(address,address,uint256,uint256)")),
                from,
                token,
                depositAmount,
                redeemAmount));
        engine.expose_redeemCollateral(from,to,token,redeemAmount);
    }
    /*
    function test_redeemInsufficientBalanceWbtc(
        address from,
        address to,
        address token,
        uint256 redeemAmount,
        uint256 depositAmount
        ) external skipIfNotOnAnvil
    {
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        vm.assume(redeemAmount > depositAmount);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        (,token,,,,) = config.s_activeChainConfig();
        // mint collateral token to fromuser
        ERC20Mock(token).mint(from,depositAmount);
        // fromuser approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(from);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // fromuser deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedRedeemAmountExceedsBalance(address,address,uint256,uint256)")),
                from,
                token,
                depositAmount,
                redeemAmount));
        engine.expose_redeemCollateral(from,to,token,redeemAmount);
    }
    */
    function test_redeemOutsideRedeemLimitsWeth(
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        (address token,,,,,) = config.s_activeChainConfig();
        _redeemOutsideRedeemLimits(
            from,
            to,
            token,
            redeemAmount,
            depositAmount,
            mintAmount);
    }
    function test_redeemOutsideRedeemLimitsWbtc(
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        (,address token,,,,) = config.s_activeChainConfig();
        _redeemOutsideRedeemLimits(
            from,
            to,
            token,
            redeemAmount,
            depositAmount,
            mintAmount);
    }
    function _redeemOutsideRedeemLimits(
        address from,
        address to,
        address token,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) internal
    {
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        // mint collateral token to from user
        ERC20Mock(token).mint(from,depositAmount);
        // fromuser approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(from);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // fromuser deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        // calc max mint amount given specific deposit amount
        uint256 maxMintAmount = engine.exposegetValueOfDepositsInUsd(from) 
            * engine.getThresholdLimitPercent() 
            / engine.getFractionRemovalMultiplier();
        mintAmount = bound(mintAmount,1,maxMintAmount);
        // fromuser mints (aka takes on debt from system)
        vm.prank(from);
        engine.mintDSC(mintAmount);
        // bound redeemAmount to be outside of redeem limit but within deposit amount
        uint256 maxSafeRedeemAmount = (maxMintAmount - mintAmount) 
                * engine.getFractionRemovalMultiplier() 
                / engine.getThresholdLimitPercent();
        maxSafeRedeemAmount = engine.exposeconvertFromUsd(maxSafeRedeemAmount,token);
        redeemAmount = bound(
            redeemAmount,
            maxSafeRedeemAmount+1,
            depositAmount);
        vm.assume(redeemAmount > 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedRedeemAmountBreachesUserRedeemLimit(address,address,uint256,uint256)")),
                from,
                token,
                redeemAmount,
                maxSafeRedeemAmount));
        engine.expose_redeemCollateral(from,to,token,redeemAmount);
    }
    /*
    function test_redeemOutsideRedeemLimitsWbtc(
        address from,
        address to,
        address token,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil
    {
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        (,token,,,,) = config.s_activeChainConfig();
        // mint collateral token to from user
        ERC20Mock(token).mint(from,depositAmount);
        // fromuser approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(from);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // fromuser deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        // calc max mint amount given specific deposit amount
        uint256 maxMintAmount = engine.exposegetValueOfDepositsInUsd(from) 
            * engine.getThresholdLimitPercent() 
            / engine.getFractionRemovalMultiplier();
        mintAmount = bound(mintAmount,1,maxMintAmount);
        // fromuser mints (aka takes on debt from system)
        vm.prank(from);
        engine.mintDSC(mintAmount);
        // bound redeemAmount to be outside of redeem limit but within deposit amount
        uint256 maxSafeRedeemAmount = (maxMintAmount - mintAmount) 
                * engine.getFractionRemovalMultiplier() 
                / engine.getThresholdLimitPercent();
        maxSafeRedeemAmount = engine.exposeconvertFromUsd(maxSafeRedeemAmount,token);
        redeemAmount = bound(
            redeemAmount,
            maxSafeRedeemAmount+1,
            depositAmount);
        vm.assume(redeemAmount > 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedRedeemAmountBreachesUserRedeemLimit(address,address,uint256,uint256)")),
                from,
                token,
                redeemAmount,
                maxSafeRedeemAmount));
        engine.expose_redeemCollateral(from,to,token,redeemAmount);
    }
    */
    function test_redeemStateCorrectlyUpdatedWeth(
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        (address token,,,,,) = config.s_activeChainConfig();
        _redeemStateCorrectlyUpdated(
            from,
            to,
            token,
            redeemAmount,
            depositAmount,
            mintAmount);
    }
    function test_redeemStateCorrectlyUpdatedWbtc(
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        (,address token,,,,) = config.s_activeChainConfig();
        _redeemStateCorrectlyUpdated(
            from,
            to,
            token,
            redeemAmount,
            depositAmount,
            mintAmount);
    }
    function _redeemStateCorrectlyUpdated(
        address from,
        address to,
        address token,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) internal
    {
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        // bound deposit amount to within max token balance
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        vm.assume(from != address(engine));
        vm.assume(to != address(engine));
        // mint collateral token to fromuser
        ERC20Mock(token).mint(from,depositAmount);
        // fromuser approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(from);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // fromuser deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        // calc max mint amount allowed by system given specific deposit amount
        uint256 maxMintAmount = engine.exposegetValueOfDepositsInUsd(from) 
            * engine.getThresholdLimitPercent() 
            / engine.getFractionRemovalMultiplier();
        // bound mint amount to within max mint amount allowed
        mintAmount = bound(mintAmount,1,maxMintAmount);
        // fromuser mints (aka takes on debt from system)
        vm.prank(from);
        engine.mintDSC(mintAmount);
        // calc max redeem amount allowed by system given specific deposit amount 
        //  and specific mint amount
        uint256 maxSafeRedeemAmount = (maxMintAmount - mintAmount) 
                * engine.getFractionRemovalMultiplier() 
                / engine.getThresholdLimitPercent();
        maxSafeRedeemAmount = engine.exposeconvertFromUsd(maxSafeRedeemAmount,token);
        // bound redeemAmount to be within max redeem amount allowed
        redeemAmount = bound(
            redeemAmount,
            0,
            maxSafeRedeemAmount);
        // restart run if redeem amount is 0
        vm.assume(redeemAmount != 0);
        // perform redemption and do the tests:
        //  1. check for emit
        //  2. check that fromuser deposit is drawn down by redeem amount
        //  3. check that engine collateral token balance is drawn down by redeem amount
        //  4. check that tomuser collateral token balance is increased by redeem amount
        vm.prank(from);
        uint256 depositAmountBeforeRedeem = engine.getDepositAmount(token);
        uint256 engineTokenBalanceBeforeRedeem = ERC20Mock(token).balanceOf(address(engine));
        uint256 touserTokenBalanceBeforeRedeem = ERC20Mock(token).balanceOf(to);
        // check for emit
        vm.expectEmit(true,true,true,false,address(engine));
        emit DSCEngine.CollateralRedeemed(from,token,redeemAmount);
        engine.expose_redeemCollateral(from,to,token,redeemAmount);
        // check that fromuser deposit is drawn down by redeem amount
        vm.startPrank(from);
        assertEq(engine.getDepositAmount(token),depositAmountBeforeRedeem - redeemAmount);
        vm.stopPrank();
        // check that engine collateral token balance is drawn down by redeem amount
        assertEq(ERC20Mock(token).balanceOf(address(engine)),engineTokenBalanceBeforeRedeem - redeemAmount);
        // check that tomuser collateral token balance is increased by redeem amount
        assertEq(ERC20Mock(token).balanceOf(to),touserTokenBalanceBeforeRedeem + redeemAmount);
    }
    /*
    function test_redeemStateCorrectlyUpdatedWbtc(
        address from,
        address to,
        address token,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil
    {
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        // bound deposit amount to within max token balance
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        (,token,,,,) = config.s_activeChainConfig();
        // mint collateral token to fromuser
        ERC20Mock(token).mint(from,depositAmount);
        // fromuser approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(from);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // fromuser deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        // calc max mint amount allowed by system given specific deposit amount
        uint256 maxMintAmount = engine.exposegetValueOfDepositsInUsd(from) 
            * engine.getThresholdLimitPercent() 
            / engine.getFractionRemovalMultiplier();
        // bound mint amount to within max mint amount allowed
        mintAmount = bound(mintAmount,1,maxMintAmount);
        // fromuser mints (aka takes on debt from system)
        vm.prank(from);
        engine.mintDSC(mintAmount);
        // calc max redeem amount allowed by system given specific deposit amount 
        //  and specific mint amount
        uint256 maxSafeRedeemAmount = (maxMintAmount - mintAmount) 
                * engine.getFractionRemovalMultiplier() 
                / engine.getThresholdLimitPercent();
        maxSafeRedeemAmount = engine.exposeconvertFromUsd(maxSafeRedeemAmount,token);
        // bound redeemAmount to be within max redeem amount allowed
        redeemAmount = bound(
            redeemAmount,
            0,
            maxSafeRedeemAmount);
        // restart run if redeem amount is 0
        vm.assume(redeemAmount != 0);
        // perform redemption and do the tests:
        //  1. check for emit
        //  2. check that fromuser deposit is drawn down by redeem amount
        //  3. check that engine collateral token balance is drawn down by redeem amount
        //  4. check that tomuser collateral token balance is increased by redeem amount
        vm.prank(from);
        uint256 depositAmountBeforeRedeem = engine.getDepositAmount(token);
        uint256 engineTokenBalanceBeforeRedeem = ERC20Mock(token).balanceOf(address(engine));
        uint256 touserTokenBalanceBeforeRedeem = ERC20Mock(token).balanceOf(to);
        // check for emit
        vm.expectEmit(true,true,true,false,address(engine));
        emit DSCEngine.CollateralRedeemed(from,token,redeemAmount);
        engine.expose_redeemCollateral(from,to,token,redeemAmount);
        // check that fromuser deposit is drawn down by redeem amount
        vm.startPrank(from);
        assertEq(engine.getDepositAmount(token),depositAmountBeforeRedeem - redeemAmount);
        vm.stopPrank();
        // check that engine collateral token balance is drawn down by redeem amount
        assertEq(ERC20Mock(token).balanceOf(address(engine)),engineTokenBalanceBeforeRedeem - redeemAmount);
        // check that tomuser collateral token balance is increased by redeem amount
        assertEq(ERC20Mock(token).balanceOf(to),touserTokenBalanceBeforeRedeem + redeemAmount);
    }
    */

    ////////////////////////////////////////////////////////////////////
    // Unit tests for _burnDSC()
    ////////////////////////////////////////////////////////////////////
    function test_burnFromZeroAddress(address onBehalfOf,uint256 amount) external {
        vm.assume(onBehalfOf != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__UserCannotBeZero.selector);
        engine.expose_burnDSC(address(0),onBehalfOf,amount);
    }
    function test_burnOnBehalfOfZeroAddress(address dscFrom,uint256 amount) external {
        vm.assume(dscFrom != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__UserCannotBeZero.selector);
        engine.expose_burnDSC(dscFrom,address(0),amount);
    }
    function test_burnFromZeroAddressOnBehalfOfZeroAddress(uint256 amount) external {
        vm.expectRevert(DSCEngine.DSCEngine__UserCannotBeZero.selector);
        engine.expose_burnDSC(address(0),address(0),amount);
    }
    function test_burnZeroAmount(address dscFrom,address onBehalfOf) external {
        vm.assume(dscFrom != address(0));
        vm.assume(onBehalfOf != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.expose_burnDSC(
            dscFrom,
            onBehalfOf,
            0);
    }
    function test_burnInsufficientBalance(
        address dscFrom,
        address onBehalfOf,
        uint256 burnAmount,
        uint256 amountHeld
        ) external 
    {
        vm.assume(amountHeld != 0);
        vm.assume(burnAmount > amountHeld);
        vm.assume(dscFrom != address(0));
        vm.assume(onBehalfOf != address(0));
        vm.prank(address(engine));
        coin.mint(dscFrom,amountHeld);
        assertEq(
            coin.balanceOf(dscFrom),
            amountHeld);
        assertGt(burnAmount,amountHeld);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedBurnAmountExceedsBalance(address,uint256,uint256)")),
                dscFrom,
                amountHeld,
                burnAmount));
        engine.expose_burnDSC(
            dscFrom,
            onBehalfOf,
            burnAmount);
    }
    function test_burnStateCorrectlyUpdatedWeth(
        uint256 amountDSCTokensHeld,
        uint256 amountDSCMintDebt,
        uint256 burnAmount,
        uint256 depositAmount,
        address dscFrom,
        address onBehalfOf
        ) external skipIfNotOnAnvil 
    {
        (address token,,,,,) = config.s_activeChainConfig();
        _burnStateCorrectlyUpdated(
            token,
            amountDSCTokensHeld,
            amountDSCMintDebt,
            burnAmount,
            depositAmount,
            dscFrom,
            onBehalfOf);
    }
    function test_burnStateCorrectlyUpdatedWbtc(
        uint256 amountDSCTokensHeld,
        uint256 amountDSCMintDebt,
        uint256 burnAmount,
        uint256 depositAmount,
        address dscFrom,
        address onBehalfOf
        ) external skipIfNotOnAnvil 
    {
        (,address token,,,,) = config.s_activeChainConfig();
        _burnStateCorrectlyUpdated(
            token,
            amountDSCTokensHeld,
            amountDSCMintDebt,
            burnAmount,
            depositAmount,
            dscFrom,
            onBehalfOf);
    }
    function _burnStateCorrectlyUpdated(
        address token,
        uint256 amountDSCTokensHeld,
        uint256 amountDSCMintDebt,
        uint256 burnAmount,
        uint256 depositAmount,
        address dscFrom,
        address onBehalfOf
        ) internal
    {
        // setup
        //  1. mint enough DSC tokens for dscFrom to burn
        //  2. dscFrom approves sufficient allowance to engine for burn amount
        //  3. mint enough collateral tokens for onBehalfOf to deposit
        //  4. onBehalfOf deposits collaterals and mints DSC (aka take on debt) for 
        //      the liquidation burn
        vm.assume(dscFrom != address(0));
        vm.assume(onBehalfOf != address(0));
        uint256 maxDSCTokensHeld = 1e9;    // 1 billion DSC tokens, arbitrary limit to avoid math overflow
        amountDSCTokensHeld = bound(amountDSCTokensHeld,3,maxDSCTokensHeld);
        amountDSCMintDebt = bound(amountDSCMintDebt,2,amountDSCTokensHeld);
        burnAmount = bound(burnAmount,1,amountDSCMintDebt);
        // mint DSC tokens for dscFrom to burn
        //  note that engine is the one to call DecentralizedStableCoin.mint(), because it has an owner 
        //  restriction, and that the engine is the owner of DecentralizedStableCoin. 
        //  hence this pranking of the engine is needed for this mint
        vm.prank(address(engine));
        coin.mint(dscFrom,amountDSCTokensHeld);
        // dscFrom approves sufficient allowance to engine for burn amount
        //  approval definitely needs pranking of dscFrom
        vm.prank(dscFrom);
        coin.approve(address(engine),amountDSCTokensHeld);
        assertEq(
            coin.balanceOf(dscFrom),
            amountDSCTokensHeld);
        assertGe(amountDSCTokensHeld,burnAmount);
        assertGe(coin.allowance(dscFrom,address(engine)),burnAmount);

        uint256 minDepositValueNeeded = 1 + amountDSCMintDebt 
            * engine.getFractionRemovalMultiplier() 
            / engine.getThresholdLimitPercent();
        uint256 maxDepositValueNeeded = 1 + amountDSCTokensHeld 
            * engine.getFractionRemovalMultiplier() 
            / engine.getThresholdLimitPercent();
        uint256 minDepositAmountNeeded = 1 + engine.exposeconvertFromUsd(minDepositValueNeeded,token);
        uint256 maxDepositAmountNeeded = 1 + engine.exposeconvertFromUsd(maxDepositValueNeeded,token);
        depositAmount = bound(depositAmount,minDepositAmountNeeded,maxDepositAmountNeeded);
        // mint enough ETH tokens for onBehalfOf to deposit as collaterals
        //  minting here doesn't need pranking because ERC20Mock.mint() doesn't have an owner 
        //  restriction
        ERC20Mock(token).mint(onBehalfOf,depositAmount);
        // onBehalfOf approves a sufficient allowance for the engine to transfer during deposit
        //  approval definitely needs pranking of onBehalfOf
        vm.startPrank(onBehalfOf);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // onBehalfOf deposits the ETH (ie: onBehalfOf calls depositCollateral())
        //  note that in the deposit process, it is the engine that does the transfer of tokens 
        //  from onBehalfOf to the engine itself, hence the earlier approval by onBehalfOf to
        //  the engine for the deposit amount was needed
        engine.depositCollateral(token,depositAmount);
        // and mints DSC (aka take on debt) for the liquidation burn
        //  note that it is also onBehalfOf that calls mintDSC()
        engine.mintDSC(amountDSCMintDebt);
        assertEq(depositAmount,engine.getDepositAmount(token));
        assertEq(amountDSCMintDebt,engine.getMints());
        vm.stopPrank();

        // start the burn and do the tests
        //  1. check for emit
        //  2. check that onBehalfOf DSC mint debt is drawn down by burn amount
        //  3. check that dscFrom DSC token balance is drawn down by burn amount
        //  4. check that DSC token total supply is drawn down by burn amount
        uint256 dscTotalSupplyBeforeBurn = coin.totalSupply();
        // setup to check for emit
        //  note that it is the engine that will call expose_burnDSC()
        //  note also that earlier dscFrom approved the engine for the burn amount
        //  so that the engine can do the transfer of DSC tokens from dscFrom to
        //  the engine itself to be burned
        vm.startPrank(address(engine));
        vm.expectEmit(true,true,false,false,address(engine));
        emit DSCEngine.DSCBurned(onBehalfOf,burnAmount);
        // start the burn!!
        engine.expose_burnDSC(dscFrom,onBehalfOf,burnAmount);
        vm.stopPrank();
        // check that onBehalfOf DSC mint debt is drawn down by burn amount
        vm.startPrank(onBehalfOf);
        assertEq(engine.getMints(),amountDSCMintDebt - burnAmount);
        vm.stopPrank();
        // check that dscFrom DSC token balance is drawn down by burn amount
        assertEq(coin.balanceOf(dscFrom),amountDSCTokensHeld - burnAmount);
        // check that DSC token total supply is drawn down by burn amount
        assertEq(coin.totalSupply(),dscTotalSupplyBeforeBurn - burnAmount);
    }
    /*
    function test_burnStateCorrectlyUpdatedWbtc(
        uint256 amountDSCTokensHeld,
        uint256 amountDSCMintDebt,
        uint256 burnAmount,
        uint256 depositAmount,
        address dscFrom,
        address onBehalfOf
        ) external skipIfNotOnAnvil
    {
        // setup
        //  1. mint enough DSC tokens for dscFrom to burn
        //  2. dscFrom approves sufficient allowance to engine for burn amount
        //  3. mint enough ETH tokens for onBehalfOf to deposit as collaterals
        //  4. onBehalfOf deposits ETH and mints DSC (aka take on debt) for 
        //      the liquidation burn
        vm.assume(dscFrom != address(0));
        vm.assume(onBehalfOf != address(0));
        uint256 maxDSCTokensHeld = 1e9;    // 1 billion DSC tokens, arbitrary limit to avoid math overflow
        amountDSCTokensHeld = bound(amountDSCTokensHeld,3,maxDSCTokensHeld);
        amountDSCMintDebt = bound(amountDSCMintDebt,2,amountDSCTokensHeld);
        burnAmount = bound(burnAmount,1,amountDSCMintDebt);
        // mint enough DSC tokens for dscFrom to burn
        vm.prank(address(engine));
        coin.mint(dscFrom,amountDSCTokensHeld);
        // dscFrom approves sufficient allowance to engine for burn amount
        vm.prank(dscFrom);
        coin.approve(address(engine),amountDSCTokensHeld);
        assertEq(
            coin.balanceOf(dscFrom),
            amountDSCTokensHeld);
        assertGe(amountDSCTokensHeld,burnAmount);
        assertGe(coin.allowance(dscFrom,address(engine)),burnAmount);

        uint256 minDepositValueNeeded = 1 + amountDSCMintDebt 
            * engine.getFractionRemovalMultiplier() 
            / engine.getThresholdLimitPercent();
        uint256 maxDepositValueNeeded = 1 + amountDSCTokensHeld 
            * engine.getFractionRemovalMultiplier() 
            / engine.getThresholdLimitPercent();
        (,address token,,,,) = config.s_activeChainConfig();
        uint256 minDepositAmountNeeded = 1 + engine.exposeconvertFromUsd(minDepositValueNeeded,token);
        uint256 maxDepositAmountNeeded = 1 + engine.exposeconvertFromUsd(maxDepositValueNeeded,token);
        depositAmount = bound(depositAmount,minDepositAmountNeeded,maxDepositAmountNeeded);
        // mint enough ETH tokens for onBehalfOf to deposit as collaterals
        ERC20Mock(token).mint(onBehalfOf,depositAmount);
        vm.startPrank(onBehalfOf);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // onBehalfOf deposits the ETH
        engine.depositCollateral(token,depositAmount);
        // and mints DSC (aka take on debt) for the liquidation burn
        engine.mintDSC(amountDSCMintDebt);
        assertEq(depositAmount,engine.getDepositAmount(token));
        assertEq(amountDSCMintDebt,engine.getMints());
        vm.stopPrank();

        // start the burn and do the tests
        //  1. check for emit
        //  2. check that onBehalfOf DSC mint debt is drawn down by burn amount
        //  3. check that dscFrom DSC token balance is drawn down by burn amount
        //  4. check that DSC token total supply is drawn down by burn amount
        uint256 dscTotalSupplyBeforeBurn = coin.totalSupply();
        // setup to check for emit
        vm.startPrank(address(engine));
        vm.expectEmit(true,true,false,false,address(engine));
        emit DSCEngine.DSCBurned(onBehalfOf,burnAmount);
        // start the burn!!
        engine.expose_burnDSC(dscFrom,onBehalfOf,burnAmount);
        vm.stopPrank();
        // check that onBehalfOf DSC mint debt is drawn down by burn amount
        vm.startPrank(onBehalfOf);
        assertEq(engine.getMints(),amountDSCMintDebt - burnAmount);
        vm.stopPrank();
        // check that dscFrom DSC token balance is drawn down by burn amount
        assertEq(coin.balanceOf(dscFrom),amountDSCTokensHeld - burnAmount);
        // check that DSC token total supply is drawn down by burn amount
        assertEq(coin.totalSupply(),dscTotalSupplyBeforeBurn - burnAmount);
    }
    */

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
    function testGetAllowedTokensOutOfRange(uint256 index) external {
        uint256 arrayLength = engine.getAllowedCollateralTokensArrayLength();
        vm.assume(index >= arrayLength);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__OutOfArrayRange(uint256,uint256)")),
                arrayLength - 1,
                index));
        engine.getAllowedCollateralTokens(index);
    }
    function testGetAllowedTokens() external view {
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        assertEq(weth,engine.getAllowedCollateralTokens(0));
        assertEq(wbtc,engine.getAllowedCollateralTokens(1));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getPriceFeed()
    ////////////////////////////////////////////////////////////////////
    function testGetPriceFeedZeroToken() external {
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        engine.getPriceFeed(address(0));
    }
    function testGetPriceFeedNonAllowedToken(address token) external {
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        vm.assume(token != address(0));
        vm.assume(token != weth);
        vm.assume(token != wbtc);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__TokenNotAllowed(address)")),
                token));
        engine.getPriceFeed(token);
    }
    function testGetPriceFeedAllowedToken() external view {
        (
            address weth,
            address wbtc,
            address wethPriceFeed,
            address wbtcPriceFeed,
            uint256 wethPrecision,
            uint256 wbtcPrecision) = config.s_activeChainConfig();
        (address engineWethPriceFeed,uint256 engineWethPrecision) = engine.getPriceFeed(weth);
        (address engineWbtcPriceFeed,uint256 engineWbtcPrecision) = engine.getPriceFeed(wbtc);
        assertEq(wethPriceFeed,engineWethPriceFeed);
        assertEq(wbtcPriceFeed,engineWbtcPriceFeed);
        assertEq(wethPrecision,engineWethPrecision);
        assertEq(wbtcPrecision,engineWbtcPrecision);
    }
}