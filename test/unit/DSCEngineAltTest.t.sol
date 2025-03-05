// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ChainConfigurator} from "../../script/ChainConfigurator.s.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {ChangeOwner} from "../../script/ChangeOwner.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAggregatorV3} from "../../test/mocks/MockAggregatorV3.sol";

contract DSCEngineAltTest is Test {
    DecentralizedStableCoin public coin;
    DSCEngine public engine;
    ChainConfigurator public config;
    DeployDSC public deployer;
    ChangeOwner public changeOwner;
    address public USER;

    ///////////////////////////////////////////////////////////////////////////////////
    // mechanism to check if test functions run to completion//////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    // unfortunately this works only for non-fuzz tests, which renders it useless for
    //  most tests
    /*
    uint256 public toTheEndTestCounts;
    bool public completion; // set this to true in setUp() to begin
    // include following line in an appropriate place near the end of a test function
    //  if (completion) {console.log("toTheEndTestCounts: ",++toTheEndTestCounts);}
    */
    ///////////////////////////////////////////////////////////////////////////////////

    /* Modifiers */
    modifier skipIfNotOnAnvil() {
        if (block.chainid != vm.envUint("DEFAULT_ANVIL_CHAINID")) {
            return;
        }
        _;
    }
    /*
    modifier toTheEnd() {
        _;
        ++toTheEndTestCounts;
        console.log("toTheEndTestCounts: ",toTheEndTestCounts);
    }
    */

    /* Setup Function */
    function setUp() external {
        // deploy coin and engine together
        deployer = new DeployDSC();
        (coin,engine,config) = deployer.run();

        // change ownership of coin to engine
        // this project assumes deployment only to mainnet, sepolia testnet, and Anvil
        if (block.chainid == vm.envUint("ETH_MAINNET_CHAINID")) {
            // for testnet and mainnet we need to wait ~15 seconds for the deployment
            // transactions block to be confirmed 1st before calling the ChangeOwner script
            changeOwner = new ChangeOwner();
            changeOwner.run();
        } else if (block.chainid == vm.envUint("ETH_SEPOLIA_CHAINID")) {
            // for testnet and mainnet we need to wait ~15 seconds for the deployment
            // transactions block to be confirmed 1st before calling the ChangeOwner script
            changeOwner = new ChangeOwner();
            changeOwner.run();
        } else {
            // these lines work only under Anvil where the deployment transactions
            // block is confirmed fast enough to immediately do the ownership transfer
            vm.prank(coin.owner());
            coin.transferOwnership(address(engine));
        }

        // prepare generic prank user; balances and approvals better to setup within 
        //  each test according to needs of situation
        USER = makeAddr("user");
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for constructor()
    ////////////////////////////////////////////////////////////////////
    function testDscTokenAddressCannotBeZero(uint256 thresholdLimit) external {
        address[] memory addrArray;
        uint256[] memory uintArray;
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        new DSCEngine(addrArray,addrArray,uintArray,address(0),thresholdLimit);
    }
    function testValidDscToken() external view {
        assert(engine.i_dscToken() == address(coin));
    }
    function testThresholdPercentWithinRange() external view {
        assert(engine.i_thresholdLimitPercent() >= 1);
        assert(engine.i_thresholdLimitPercent() <= 99);
    }
    function testValidThresholdPercent() external view {
        assert(engine.i_thresholdLimitPercent() == vm.envUint("THRESHOLD_PERCENT"));
    }
    function testConstructorInputParamsMismatch(
        address token,
        uint256 arrayOneLength,
        uint256 arrayTwoLength,
        uint256 arrayThreeLength,
        uint256 threshold) external 
    {
        vm.assume(token != address(0));
        threshold = bound(threshold,1,99);
        arrayOneLength = bound(arrayOneLength,1,256);
        arrayTwoLength = bound(arrayTwoLength,1,256);
        arrayThreeLength = bound(arrayThreeLength,1,256);
        if (!(
            (arrayOneLength == arrayTwoLength) &&
            (arrayTwoLength == arrayThreeLength))) 
        {
            address[] memory arrayOne = new address[](arrayOneLength);
            address[] memory arrayTwo = new address[](arrayTwoLength);
            uint256[] memory arrayThree = new uint256[](arrayThreeLength);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__ConstructorInputParamsMismatch(uint256,uint256,uint256)")),
                    arrayOne.length,
                    arrayTwo.length,
                    arrayThree.length));
            new DSCEngine(arrayOne,arrayTwo,arrayThree,token,threshold);
        }
    }
    function testCollateralTokenAddressCannotBeZero(
        address token,
        uint256 arrayLength,
        uint256 threshold
        ) external 
    {
        vm.assume(token != address(0));
        arrayLength = bound(arrayLength,1,256);
        threshold = bound(threshold,1,99);
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        uint256[] memory arrayPrecision = new uint256[](arrayLength);
        arrayCollateral[0] = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,arrayPrecision,token,threshold);
    }
    function testPriceFeedAddressCannotBeZero(
        address token,
        uint256 arrayLength,
        uint256 threshold
        ) external 
    {
        vm.assume(token != address(0));
        arrayLength = bound(arrayLength,1,256);
        threshold = bound(threshold,1,99);
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        uint256[] memory arrayPrecision = new uint256[](arrayLength);
        arrayCollateral[0] = makeAddr("collateral");
        arrayPriceFeed[0] = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__PriceFeedAddressCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,arrayPrecision,token,threshold);
    }
    function testPriceFeedPrecisionCannotBeZero(
        address token,
        uint256 arrayLength,
        uint256 threshold
        ) external 
    {
        vm.assume(token != address(0));
        arrayLength = bound(arrayLength,1,256);
        threshold = bound(threshold,1,99);
        address[] memory arrayCollateral = new address[](arrayLength);
        address[] memory arrayPriceFeed = new address[](arrayLength);
        uint256[] memory arrayPrecision = new uint256[](arrayLength);
        arrayCollateral[0] = makeAddr("collateral");
        arrayPriceFeed[0] = makeAddr("price feed");
        arrayPrecision[0] = 0;
        vm.expectRevert(DSCEngine.DSCEngine__PriceFeedPrecisionCannotBeZero.selector);
        new DSCEngine(arrayCollateral,arrayPriceFeed,arrayPrecision,token,threshold);
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
    function testGetAllDeposits(uint256 wethDeposit,uint256 wbtcDeposit) external skipIfNotOnAnvil {
        uint256 maxDeposit = 1e9;   // 1 billion tokens
        wethDeposit = bound(wethDeposit,1,maxDeposit);
        wbtcDeposit = bound(wbtcDeposit,1,maxDeposit);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        ERC20Mock(weth).mint(USER,wethDeposit);
        ERC20Mock(wbtc).mint(USER,wbtcDeposit);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),wethDeposit);
        ERC20Mock(wbtc).approve(address(engine),wbtcDeposit);
        engine.depositCollateral(weth,wethDeposit);
        engine.depositCollateral(wbtc,wbtcDeposit);
        vm.stopPrank();

        vm.prank(USER);
        DSCEngine.Holding[] memory deposits = engine.getAllDeposits();

        // weth tests
        assertEq(deposits[0].token,weth);
        assertEq(deposits[0].isCollateral,true);
        assertEq(deposits[0].amount,wethDeposit);
        assertEq(deposits[0].currentPrice,engine.convertToUsd(weth,1));
        assertEq(deposits[0].currentValueInUsd,engine.convertToUsd(weth,wethDeposit));
        // wbtc tests
        assertEq(deposits[1].token,wbtc);
        assertEq(deposits[1].isCollateral,true);
        assertEq(deposits[1].amount,wbtcDeposit);
        assertEq(deposits[1].currentPrice,engine.convertToUsd(wbtc,1));
        assertEq(deposits[1].currentValueInUsd,engine.convertToUsd(wbtc,wbtcDeposit));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getDepositAmount()
    ////////////////////////////////////////////////////////////////////
    function testGetDepositAmountZeroToken() external {
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("DSCEngine__InvalidToken(address)")),
            address(0)));
        engine.getDepositAmount(address(0));
    }
    function testGetDepositAmountInvalidToken(address token) external {
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        vm.assume(token != address(0));
        vm.assume(token != weth);
        vm.assume(token != wbtc);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("DSCEngine__InvalidToken(address)")),
            token));
        engine.getDepositAmount(token);
    }
    function testGetDepositAmount(uint256 wethDeposit,uint256 wbtcDeposit) external skipIfNotOnAnvil {
        uint256 maxDeposit = 1e9;   // 1 billion tokens
        wethDeposit = bound(wethDeposit,1,maxDeposit);
        wbtcDeposit = bound(wbtcDeposit,1,maxDeposit);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        ERC20Mock(weth).mint(USER,wethDeposit);
        ERC20Mock(wbtc).mint(USER,wbtcDeposit);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),wethDeposit);
        ERC20Mock(wbtc).approve(address(engine),wbtcDeposit);
        engine.depositCollateral(weth,wethDeposit);
        engine.depositCollateral(wbtc,wbtcDeposit);
        vm.stopPrank();

        // weth test
        vm.startPrank(USER);
        assertEq(wethDeposit,engine.getDepositAmount(weth));
        // wbtc test
        assertEq(wbtcDeposit,engine.getDepositAmount(wbtc));
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getDepositsValueInUsd()
    ////////////////////////////////////////////////////////////////////
    function testGetDepositsValueInUsd(uint256 wethDeposit,uint256 wbtcDeposit) external skipIfNotOnAnvil {
        uint256 maxDeposit = 1e9;   // 1 billion tokens
        wethDeposit = bound(wethDeposit,1,maxDeposit);
        wbtcDeposit = bound(wbtcDeposit,1,maxDeposit);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        ERC20Mock(weth).mint(USER,wethDeposit);
        ERC20Mock(wbtc).mint(USER,wbtcDeposit);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),wethDeposit);
        ERC20Mock(wbtc).approve(address(engine),wbtcDeposit);
        engine.depositCollateral(weth,wethDeposit);
        engine.depositCollateral(wbtc,wbtcDeposit);
        vm.stopPrank();

        vm.startPrank(USER);
        assertEq(
            engine.getDepositsValueInUsd(),
            (
                engine.convertToUsd(weth,engine.getDepositAmount(weth)) + 
                engine.convertToUsd(wbtc,engine.getDepositAmount(wbtc))
            ));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getMints()
    ////////////////////////////////////////////////////////////////////
    function testGetMints(uint256 wethDeposit,uint256 wbtcDeposit,uint256 mintAmount) external skipIfNotOnAnvil {
        uint256 maxDeposit = 1e9;   // 1 billion tokens
        wethDeposit = bound(wethDeposit,1,maxDeposit);
        wbtcDeposit = bound(wbtcDeposit,1,maxDeposit);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        ERC20Mock(weth).mint(USER,wethDeposit);
        ERC20Mock(wbtc).mint(USER,wbtcDeposit);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),wethDeposit);
        ERC20Mock(wbtc).approve(address(engine),wbtcDeposit);
        engine.depositCollateral(weth,wethDeposit);
        engine.depositCollateral(wbtc,wbtcDeposit);

        uint256 maxSafeMintAmount = engine.getDepositsValueInUsd() 
            * engine.i_thresholdLimitPercent() 
            / engine.FRACTION_REMOVAL_MULTIPLIER();
        mintAmount = bound(mintAmount,1,maxSafeMintAmount);
        engine.mintDSC(mintAmount);
        vm.stopPrank();

        // do the test
        vm.prank(USER);
        assertEq(mintAmount,engine.getMints());
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getMintsValueInUsd()
    // Skipped. Same test procedure and outcome as getMints()
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getTokensHeld()
    ////////////////////////////////////////////////////////////////////
    function testGetTokensHeld(uint256 wethDeposit,uint256 wbtcDeposit,uint256 mintAmount) external skipIfNotOnAnvil {
        uint256 maxDeposit = 1e9;   // 1 billion tokens
        wethDeposit = bound(wethDeposit,1,maxDeposit);
        wbtcDeposit = bound(wbtcDeposit,1,maxDeposit);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        ERC20Mock(weth).mint(USER,wethDeposit);
        ERC20Mock(wbtc).mint(USER,wbtcDeposit);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),wethDeposit);
        ERC20Mock(wbtc).approve(address(engine),wbtcDeposit);
        engine.depositCollateral(weth,wethDeposit);
        engine.depositCollateral(wbtc,wbtcDeposit);

        uint256 maxSafeMintAmount = engine.getDepositsValueInUsd() 
            * engine.i_thresholdLimitPercent() 
            / engine.FRACTION_REMOVAL_MULTIPLIER();
        mintAmount = bound(mintAmount,1,maxSafeMintAmount);
        engine.mintDSC(mintAmount);
        vm.stopPrank();

        vm.prank(USER);
        DSCEngine.Holding[] memory tokens = engine.getTokensHeld();

        // dsc token tests
        assertEq(tokens[0].token,engine.i_dscToken());
        assertEq(tokens[0].isCollateral,false);
        assertEq(tokens[0].amount,mintAmount);
        assertEq(tokens[0].currentPrice,1);
        assertEq(tokens[0].currentValueInUsd,mintAmount);
        // weth tests
        assertEq(tokens[1].token,weth);
        assertEq(tokens[1].isCollateral,true);
        assertEq(tokens[1].amount,wethDeposit);
        assertEq(tokens[1].currentPrice,engine.convertToUsd(weth,1));
        assertEq(tokens[1].currentValueInUsd,engine.convertToUsd(weth,wethDeposit));
        // wbtc tests
        assertEq(tokens[2].token,wbtc);
        assertEq(tokens[2].isCollateral,true);
        assertEq(tokens[2].amount,wbtcDeposit);
        assertEq(tokens[2].currentPrice,engine.convertToUsd(wbtc,1));
        assertEq(tokens[2].currentValueInUsd,engine.convertToUsd(wbtc,wbtcDeposit));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getTokensHeldValueInUsd()
    ////////////////////////////////////////////////////////////////////
    function testGetTokensHeldValueInUsd(uint256 wethDeposit,uint256 wbtcDeposit,uint256 mintAmount) external skipIfNotOnAnvil {
        uint256 maxDeposit = 1e9;   // 1 billion tokens
        wethDeposit = bound(wethDeposit,1,maxDeposit);
        wbtcDeposit = bound(wbtcDeposit,1,maxDeposit);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        ERC20Mock(weth).mint(USER,wethDeposit);
        ERC20Mock(wbtc).mint(USER,wbtcDeposit);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),wethDeposit);
        ERC20Mock(wbtc).approve(address(engine),wbtcDeposit);
        engine.depositCollateral(weth,wethDeposit);
        engine.depositCollateral(wbtc,wbtcDeposit);

        uint256 maxSafeMintAmount = engine.getDepositsValueInUsd() 
            * engine.i_thresholdLimitPercent() 
            / engine.FRACTION_REMOVAL_MULTIPLIER();
        mintAmount = bound(mintAmount,1,maxSafeMintAmount);
        engine.mintDSC(mintAmount);
        vm.stopPrank();

        // do the test
        vm.startPrank(USER);
        assertEq(
            engine.getTokensHeldValueInUsd(),
            engine.getDepositsValueInUsd() + engine.getMintsValueInUsd());
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for depositCollateralMintDSC()
    ////////////////////////////////////////////////////////////////////
    function testDepositCollateralMintDSC(
        uint256 tokenSeed,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil
    {
        address token;
        {
        if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
        else {(,token,,,,) = config.s_activeChainConfig();}
            uint256 maxDepositAmount = 1e9; // 1 billion collateral tokens
            depositAmount = bound(depositAmount,1,maxDepositAmount);
            // deposits value * threshold / fractional = max mint value
            //  note that since DSC is 1:1 to USD, mint value == mint amount
            uint256 threshold = engine.i_thresholdLimitPercent();
            uint256 fractional = engine.FRACTION_REMOVAL_MULTIPLIER();
            uint256 depositValue = engine.convertToUsd(token,depositAmount);
            uint256 maxMintAmount = depositValue * threshold / fractional;
            mintAmount = bound(mintAmount,1,maxMintAmount);

            // setup needed prerequisite collateral mints and approvals
            ERC20Mock(token).mint(USER,depositAmount);
            vm.prank(USER);
            ERC20Mock(token).approve(address(engine),depositAmount);
        }
        // collect the initial values
        vm.startPrank(USER);
        uint256 userCollateralBalanceBefore = ERC20Mock(token).balanceOf(USER);
        uint256 userDepositBefore = engine.getDepositAmount(token);
        uint256 userDSCBalanceBefore = coin.balanceOf(USER);
        uint256 userMintBefore = engine.getMints();
        uint256 engineCollateralBalanceBefore = ERC20Mock(token).balanceOf(address(engine));
        uint256 dscTotalSupplyBefore = coin.totalSupply();
        // check initial values
        assertEq(userCollateralBalanceBefore,depositAmount);
        assertEq(userDepositBefore,0);
        assertEq(userDSCBalanceBefore,0);
        assertEq(userMintBefore,0);
        assertEq(engineCollateralBalanceBefore,0);
        assertEq(dscTotalSupplyBefore,0);
        vm.stopPrank();

        // perform the deposit and mint
        vm.prank(USER);
        engine.depositCollateralMintDSC(token,depositAmount,mintAmount);

        // do the tests
        vm.startPrank(USER);
        assertEq(ERC20Mock(token).balanceOf(USER),userCollateralBalanceBefore-depositAmount);
        assertEq(engine.getDepositAmount(token),userDepositBefore+depositAmount);
        assertEq(coin.balanceOf(USER),userDSCBalanceBefore+mintAmount);
        assertEq(engine.getMints(),userMintBefore+mintAmount);
        assertEq(ERC20Mock(token).balanceOf(address(engine)),engineCollateralBalanceBefore+depositAmount);
        assertEq(coin.totalSupply(),dscTotalSupplyBefore+mintAmount);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for depositCollateral()
    ////////////////////////////////////////////////////////////////////
    function testDepositZeroAmount(address depositor,address token) external {
        vm.assume(depositor != address(0));
        vm.prank(depositor);
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.depositCollateral(token,0);
    }
    function testDepositTokenWithZeroAddress(address depositor,uint256 randomDepositAmount) external {
        vm.assume(depositor != address(0));
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        vm.prank(depositor);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("DSCEngine__InvalidToken(address)")),
            address(0)));
        engine.depositCollateral(address(0),randomDepositAmount);
    }
    function testDepositNonAllowedTokens(address depositor,address randomTokenAddress,uint256 randomDepositAmount) external {
        vm.assume(depositor != address(0));
        vm.assume(randomTokenAddress != address(0));
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        //vm.assume(randomDepositAmount > 0);
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<engine.getAllowedCollateralTokensArrayLength();i++) {
            if (randomTokenAddress == engine.getAllowedCollateralTokens(i)) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            // if deposit non-allowed token, revert
            vm.prank(depositor);
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                    randomTokenAddress));
            engine.depositCollateral(randomTokenAddress,randomDepositAmount);
        }
    }
    function testDepositStateCorrectlyUpdated(address depositor,uint256 randomDepositAmount) external skipIfNotOnAnvil {
        // here we check that:
        //  1. expected emit happened
        //  2. engine deposit records are correct
        //  3. depositor balance is correct
        //  4. engine balance is correct

        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the depositor some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        vm.assume(depositor != address(0));
        vm.assume(depositor != address(engine));
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        for(uint256 i=0;i<arraySize;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            // preparations needed:
            //  1. mint depositor enough collateral tokens for the deposit
            ERC20Mock(token).mint(depositor,randomDepositAmount);
            //  2. depositor to approve engine as spender with enough allowance for deposit
            vm.prank(depositor);
            ERC20Mock(token).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as depositor and check for emit
            vm.expectEmit(true,true,true,false,address(engine));
            emit DSCEngine.CollateralDeposited(depositor,token,randomDepositAmount);
            vm.prank(depositor);
            engine.depositCollateral(token,randomDepositAmount);
            // do the check
            vm.prank(depositor);
            uint256 depositHeld = engine.getDepositAmount(token);
            assertEq(depositHeld,randomDepositAmount);
            assertEq(ERC20Mock(token).balanceOf(depositor),0);
            assertEq(ERC20Mock(token).balanceOf(address(engine)),randomDepositAmount);
        }
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for mintDSC()
    ////////////////////////////////////////////////////////////////////
    function testMintZeroAmount(address minter) external {
        vm.assume(minter != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        vm.prank(minter);
        engine.mintDSC(0);
    }
    function testMintOutsideLimit(
        address minter,
        uint256 requestedMintAmount,
        uint256 valueOfDepositsHeld,
        uint256 wethDepositAmount,
        uint256 wbtcDepositAmount,
        uint256 valueOfMintsAlreadyHeld
        ) external skipIfNotOnAnvil 
    {
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

        vm.assume(minter != address(0));
        // get token address for weth and wbtc for use later
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        //  1. set arbitrary max deposit limit = 1 billion USD
        uint256 maxDepositValueInUSD = 1000000000;  // 1 billion USD
        //  2. bound valueOfDepositsHeld by max deposit limit
        valueOfDepositsHeld = bound(valueOfDepositsHeld,1,maxDepositValueInUSD);
        // get mock price of weth from .env
        uint256 wethPriceInUSD = engine.convertToUsd(weth,1);
        //  3. bound wethDepositAmount by max deposit limit
        wethDepositAmount = bound(wethDepositAmount,0,maxDepositValueInUSD/wethPriceInUSD);
        // get mock price of wbtc from .env
        uint256 wbtcPriceInUSD = engine.convertToUsd(wbtc,1);
        //  4. bound wbtcDepositAmount by max deposit limit for a particular random wethDepositAmount value
        wbtcDepositAmount = bound(
            wbtcDepositAmount,
            0,
            (maxDepositValueInUSD - engine.convertToUsd(weth,wethDepositAmount)) / wbtcPriceInUSD);
        //  5. deposit random weth and wbtc amounts via depositCollateral()
        if (wethDepositAmount > 0) {
            ERC20Mock(weth).mint(minter,wethDepositAmount);
            vm.startPrank(minter);
            ERC20Mock(weth).approve(address(engine),wethDepositAmount);
            engine.depositCollateral(weth,wethDepositAmount);
            vm.stopPrank();
        }
        if (wbtcDepositAmount > 0) {
            ERC20Mock(wbtc).mint(minter,wbtcDepositAmount);
            vm.startPrank(minter);
            ERC20Mock(wbtc).approve(address(engine),wbtcDepositAmount);
            engine.depositCollateral(wbtc,wbtcDepositAmount);
            vm.stopPrank();
        }
        //  6. calc numerator, ie: valueOfDepositsHeld * thresholdLimit
        uint256 numerator = engine.exposegetValueOfDepositsInUsd(minter) * engine.i_thresholdLimitPercent();
        //  7. bound valueOfMintsAlreadyHeld by numerator / FRACTION_REMOVAL_MULTIPLIER
        valueOfMintsAlreadyHeld = bound(valueOfMintsAlreadyHeld,0,numerator/engine.FRACTION_REMOVAL_MULTIPLIER());
        //  8. mint valueOfMintsAlreadyHeld via mintDSC()
        if (valueOfMintsAlreadyHeld > 0) {
            vm.prank(minter);
            engine.mintDSC(valueOfMintsAlreadyHeld);
        }
        //  9. bound requestedMintAmount for a particular random valueOfMintsAlreadyHeld value such that mint
        //      request is **OUTSIDE** limit
        uint256 maxSafeMintAmount = (numerator / engine.FRACTION_REMOVAL_MULTIPLIER()) - 
            engine.exposegetValueOfDscMintsInUsd(minter);
        requestedMintAmount = bound(
            requestedMintAmount,
            maxSafeMintAmount+1,
            maxDepositValueInUSD);
        //  10. perform the test by calling mintDSC() for random requestedMintAmount and checking for revert
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedMintAmountBreachesUserMintLimit(address,uint256,uint256)")),
                minter,
                requestedMintAmount,
                maxSafeMintAmount));
        engine.mintDSC(requestedMintAmount);
    }

    // Skipped. This test is already implicitly performed in testMintStateCorrectlyUpdated().
    //function testMintWithinLimit() external {}

    function testMintStateCorrectlyUpdated(
        //address minter,   // adding this input causes "stack too deep" compiler error
                            //  therefore, always minimize # of variables, input/output 
                            //  parameters, etc in a function.
                            //  this is how Solidity works.
        uint256 requestedMintAmount,
        uint256 valueOfDepositsHeld,
        uint256 wethDepositAmount,
        uint256 wbtcDepositAmount,
        uint256 valueOfMintsAlreadyHeld
        ) external skipIfNotOnAnvil 
    {
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

        //vm.assume(minter != address(0));
        // get token address for weth and wbtc for use later
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        //  1. set arbitrary max deposit limit = 1 billion USD
        uint256 maxDepositValueInUSD = 1000000000;  // 1 billion USD
        //  2. bound valueOfDepositsHeld by max deposit limit
        valueOfDepositsHeld = bound(valueOfDepositsHeld,1,maxDepositValueInUSD);
        // get mock price of weth from .env
        uint256 wethPriceInUSD = engine.convertToUsd(weth,1);
        //  3. bound wethDepositAmount by max deposit limit
        wethDepositAmount = bound(wethDepositAmount,0,maxDepositValueInUSD/wethPriceInUSD);
        // get mock price of wbtc from .env
        uint256 wbtcPriceInUSD = engine.convertToUsd(wbtc,1);
        //  4. bound wbtcDepositAmount by max deposit limit for a particular random wethDepositAmount value
        wbtcDepositAmount = bound(
            wbtcDepositAmount,
            0,
            (maxDepositValueInUSD - engine.convertToUsd(weth,wethDepositAmount)) / wbtcPriceInUSD);
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
        uint256 numerator = engine.exposegetValueOfDepositsInUsd(USER) * engine.i_thresholdLimitPercent();
        //  7. bound valueOfMintsAlreadyHeld by numerator / FRACTION_REMOVAL_MULTIPLIER
        valueOfMintsAlreadyHeld = bound(valueOfMintsAlreadyHeld,0,numerator/engine.FRACTION_REMOVAL_MULTIPLIER());
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
            (numerator/engine.FRACTION_REMOVAL_MULTIPLIER())-engine.exposegetValueOfDscMintsInUsd(USER));
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
            //      b. minted DSC balance held by user is correct
            assertEq(mintHeld,coin.totalSupply());
            //      c. total supply of DSC minted is correct
            assertEq(coin.totalSupply(),valueOfMintsAlreadyHeld + requestedMintAmount);
        }
    }

    // Skipped. This test is already performed in testMintStateCorrectlyUpdated().
    //function testEmitDSCMinted() external {}

    ////////////////////////////////////////////////////////////////////
    // Unit tests for burnDSCRedeemCollateral()
    ////////////////////////////////////////////////////////////////////
    function testBurnDSCRedeemCollateral(
        uint256 tokenSeed,
        uint256 burnAmount,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil
    {
        address token;
        {
            if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
            else {(,token,,,,) = config.s_activeChainConfig();}
            uint256 maxDepositAmount = 1e9; // 1 billion collateral tokens
            depositAmount = bound(depositAmount,1,maxDepositAmount);
            uint256 threshold = engine.i_thresholdLimitPercent();
            uint256 fractional = engine.FRACTION_REMOVAL_MULTIPLIER();
            uint256 valueOfDeposit = engine.convertToUsd(token,depositAmount);
            uint256 maxSafeMintAmount = valueOfDeposit * threshold / fractional;
            mintAmount = bound(mintAmount,1,maxSafeMintAmount);
            burnAmount = bound(burnAmount,1,mintAmount);
            // (deposit value - max redeem value) * threshold / fractional = mint value - burn value
            // max redeem value = deposit value - (mint value - burn value) * fractional / threshold
            // max redeem amount = convertFromUsd(deposit value - (mint value - burn value) * fractional / threshold)
            uint256 maxSafeRedeemAmount = engine.convertFromUsd(
                valueOfDeposit - (mintAmount - burnAmount) * fractional / threshold,token);
            // restart run if maxSafeRedeemAmount < 1, as this will cause the redeemAmount bound to fail
            vm.assume(maxSafeRedeemAmount > 0);
            //if (maxSafeRedeemAmount < 1) return;
            redeemAmount = bound(redeemAmount,1,maxSafeRedeemAmount);

            ERC20Mock(token).mint(USER,depositAmount);
            vm.startPrank(USER);
            ERC20Mock(token).approve(address(engine),depositAmount);
            engine.depositCollateral(token,depositAmount);
            engine.mintDSC(mintAmount);
            coin.approve(address(engine),burnAmount);
            vm.stopPrank();
        }

        // collect initial values
        vm.startPrank(USER);
        uint256 mintsBefore = engine.getMints();
        uint256 depositsBefore = engine.getDepositAmount(token);
        vm.stopPrank();
        uint256 userDscBalanceBefore = coin.balanceOf(USER);
        uint256 dscTotalSupplyBefore = coin.totalSupply();
        uint256 userCollateralTokenBalanceBefore = ERC20Mock(token).balanceOf(USER);
        uint256 engineCollateralTokenBalanceBefore = ERC20Mock(token).balanceOf(address(engine));
        // perform burn and redeem
        vm.startPrank(USER);
        engine.burnDSCRedeemCollateral(burnAmount,token,redeemAmount);
        // burn tests
        assertEq(engine.getMints(),mintsBefore-burnAmount);
        assertEq(coin.balanceOf(USER),userDscBalanceBefore-burnAmount);
        assertEq(coin.totalSupply(),dscTotalSupplyBefore-burnAmount);
        // redeem tests
        assertEq(engine.getDepositAmount(token),depositsBefore-redeemAmount);
        assertEq(ERC20Mock(token).balanceOf(USER),userCollateralTokenBalanceBefore+redeemAmount);
        assertEq(ERC20Mock(token).balanceOf(address(engine)),engineCollateralTokenBalanceBefore-redeemAmount);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for redeemCollateral()
    ////////////////////////////////////////////////////////////////////
    function testRedeemZeroAmount(address token) external {
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.redeemCollateral(token,0);
    }
    function testRedeemZeroTokenAddress(uint256 amount) external {
        amount = bound(amount,1,type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.redeemCollateral(address(0),amount);
    }
    function testRedeemNonAllowedToken(address token,uint256 amount) external {
        amount = bound(amount,1,type(uint256).max);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        vm.assume(token != weth);
        vm.assume(token != wbtc);
        vm.assume(token != address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                token));
        engine.redeemCollateral(token,amount);
    }
    function testRedeemInsufficientBalance(
        uint256 tokenSeed,
        uint256 redeemAmount,
        uint256 depositAmount
        ) external skipIfNotOnAnvil 
    {
        address token;
        if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
        else {(,token,,,,) = config.s_activeChainConfig();}
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        redeemAmount = bound(redeemAmount,depositAmount+1,type(uint256).max);
        // mint collateral token to USER
        ERC20Mock(token).mint(USER,depositAmount);
        // USER approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(USER);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // USER deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedRedeemAmountExceedsBalance(address,address,uint256,uint256)")),
                USER,
                token,
                depositAmount,
                redeemAmount));
        vm.prank(USER);
        engine.redeemCollateral(token,redeemAmount);
    }
    function testRedeemOutsideRedeemLimits(
        uint256 tokenSeed,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        address token;
        if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
        else {(,token,,,,) = config.s_activeChainConfig();}
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        // mint collateral token to USER
        ERC20Mock(token).mint(USER,depositAmount);
        // USER approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(USER);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // USER deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        // calc max mint amount given specific deposit amount
        uint256 maxMintAmount = engine.exposegetValueOfDepositsInUsd(USER) 
            * engine.i_thresholdLimitPercent() 
            / engine.FRACTION_REMOVAL_MULTIPLIER();
        mintAmount = bound(mintAmount,1,maxMintAmount);
        // USER mints (aka takes on debt from system)
        vm.prank(USER);
        engine.mintDSC(mintAmount);
        // bound redeemAmount to be outside of redeem limit but within deposit amount
        uint256 maxSafeRedeemAmount = (maxMintAmount - mintAmount) 
                * engine.FRACTION_REMOVAL_MULTIPLIER() 
                / engine.i_thresholdLimitPercent();
        maxSafeRedeemAmount = engine.convertFromUsd(maxSafeRedeemAmount,token);
        redeemAmount = bound(
            redeemAmount,
            maxSafeRedeemAmount+1,
            depositAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedRedeemAmountBreachesUserRedeemLimit(address,address,uint256,uint256)")),
                USER,
                token,
                redeemAmount,
                maxSafeRedeemAmount));
        vm.prank(USER);
        engine.redeemCollateral(token,redeemAmount);
    }
    function testRedeemStateCorrectlyUpdated(
        uint256 tokenSeed,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        address token;
        if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
        else {(,token,,,,) = config.s_activeChainConfig();}
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        // bound deposit amount to within max token balance
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        // mint collateral token to USER
        ERC20Mock(token).mint(USER,depositAmount);
        // USER approves sufficient allowance to engine to perform the collateral token transfer during the deposit
        vm.startPrank(USER);
        ERC20Mock(token).approve(address(engine),depositAmount);
        // USER deposits collateral into system
        engine.depositCollateral(token,depositAmount);
        vm.stopPrank();
        // calc max mint amount allowed by system given specific deposit amount
        uint256 maxMintAmount = engine.exposegetValueOfDepositsInUsd(USER) 
            * engine.i_thresholdLimitPercent() 
            / engine.FRACTION_REMOVAL_MULTIPLIER();
        // bound mint amount to within max mint amount allowed
        mintAmount = bound(mintAmount,1,maxMintAmount);
        // USER mints (aka takes on debt from system)
        vm.prank(USER);
        engine.mintDSC(mintAmount);
        // calc max redeem amount allowed by system given specific deposit amount 
        //  and specific mint amount
        uint256 maxSafeRedeemAmount = (maxMintAmount - mintAmount) 
                * engine.FRACTION_REMOVAL_MULTIPLIER() 
                / engine.i_thresholdLimitPercent();
        maxSafeRedeemAmount = engine.convertFromUsd(maxSafeRedeemAmount,token);
        // bound redeemAmount to be within max redeem amount allowed
        // restart run if maxSafeRedeemAmount < 1, as this will cause the redeemAmount bound to fail
        if (maxSafeRedeemAmount < 1) return;
        redeemAmount = bound(redeemAmount,1,maxSafeRedeemAmount);
        // restart run if redeem amount is 0
        //vm.assume(redeemAmount != 0);
        // perform redemption and do the tests:
        //  1. check for emit
        //  2. check that USER deposit is drawn down by redeem amount
        //  3. check that engine collateral token balance is drawn down by redeem amount
        //  4. check that USER collateral token balance is increased by redeem amount
        vm.prank(USER);
        uint256 depositAmountBeforeRedeem = engine.getDepositAmount(token);
        uint256 engineTokenBalanceBeforeRedeem = ERC20Mock(token).balanceOf(address(engine));
        uint256 touserTokenBalanceBeforeRedeem = ERC20Mock(token).balanceOf(USER);
        // check for emit
        vm.startPrank(USER);
        vm.expectEmit(true,true,true,false,address(engine));
        emit DSCEngine.CollateralRedeemed(USER,token,redeemAmount);
        engine.redeemCollateral(token,redeemAmount);
        // check that USER deposit is drawn down by redeem amount
        assertEq(engine.getDepositAmount(token),depositAmountBeforeRedeem - redeemAmount);
        vm.stopPrank();
        // check that engine collateral token balance is drawn down by redeem amount
        assertEq(ERC20Mock(token).balanceOf(address(engine)),engineTokenBalanceBeforeRedeem - redeemAmount);
        // check that USER collateral token balance is increased by redeem amount
        assertEq(ERC20Mock(token).balanceOf(USER),touserTokenBalanceBeforeRedeem + redeemAmount);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for burnDSC()
    ////////////////////////////////////////////////////////////////////
    function testBurnZeroAmount(address burner) external {
        vm.assume(burner != address(0));
        vm.startPrank(burner);
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.burnDSC(0);
        vm.stopPrank();
    }
    function testBurnInsufficientBalance(
        address burner,
        uint256 burnAmount,
        uint256 amountHeld
        ) external 
    {
        vm.assume(burner != address(0));
        amountHeld = bound(amountHeld,1,type(uint256).max-1);
        burnAmount = bound(burnAmount,amountHeld+1,type(uint256).max);
        //vm.assume(amountHeld != 0);
        //vm.assume(burnAmount > amountHeld);
        vm.prank(address(engine));
        coin.mint(burner,amountHeld);
        assertEq(
            coin.balanceOf(burner),
            amountHeld);
        assertGt(burnAmount,amountHeld);
        vm.startPrank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedBurnAmountExceedsBalance(address,uint256,uint256)")),
                burner,
                amountHeld,
                burnAmount));
        engine.burnDSC(burnAmount);
        vm.stopPrank();
    }
    function testBurnStateCorrectlyUpdated(
        uint256 tokenSeed,
        address burner,
        uint256 burnAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        address depositToken;
        if (tokenSeed % 2 == 0) {(depositToken,,,,,) = config.s_activeChainConfig();}
        else {(,depositToken,,,,) = config.s_activeChainConfig();}
        vm.assume(burner != address(0));
        // setup
        //  1. mint collateral tokens for burner to deposit
        //  2. burner deposits collaterals and mints DSC (aka take on debt)
        uint256 maxDepositAmount = 1e9;    // 1 billion collateral tokens, arbitrary limit to avoid math overflow
        depositAmount = bound(depositAmount,1,maxDepositAmount);
        uint256 maxMintAmount = engine.convertToUsd(depositToken,depositAmount) 
            * engine.i_thresholdLimitPercent() 
            / engine.FRACTION_REMOVAL_MULTIPLIER();
        mintAmount = bound(mintAmount,1,maxMintAmount);
        burnAmount = bound(burnAmount,1,mintAmount);
        ERC20Mock(depositToken).mint(burner,depositAmount);
        vm.startPrank(burner);
        ERC20Mock(depositToken).approve(address(engine),depositAmount);
        engine.depositCollateral(depositToken,depositAmount);
        engine.mintDSC(mintAmount);
        vm.stopPrank();

        // start the burn and do the tests
        //  1. check for emit
        //  2. check that burner DSC mint debt is drawn down by burn amount
        //  3. check that burner DSC token balance is drawn down by burn amount
        //  4. check that DSC token total supply is drawn down by burn amount
        uint256 dscTotalSupplyBeforeBurn = coin.totalSupply();
        vm.prank(burner);
        coin.approve(address(engine),burnAmount);
        // check for emit
        vm.startPrank(burner);
        vm.expectEmit(true,true,false,false,address(engine));
        emit DSCEngine.DSCBurned(burner,burnAmount);
        // start the burn!!
        engine.burnDSC(burnAmount);
        vm.stopPrank();
        // check that burner DSC mint debt is drawn down by burn amount
        vm.startPrank(burner);
        assertEq(engine.getMints(),mintAmount - burnAmount);
        vm.stopPrank();
        // check that burner DSC token balance is drawn down by burn amount
        assertEq(coin.balanceOf(burner),mintAmount - burnAmount);
        // check that DSC token total supply is drawn down by burn amount
        assertEq(coin.totalSupply(),dscTotalSupplyBeforeBurn - burnAmount);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for liquidate()
    ////////////////////////////////////////////////////////////////////
    function testLiquidateZeroUser() external {
        vm.expectRevert(DSCEngine.DSCEngine__InvalidUser.selector);
        engine.liquidate(address(0));
    }
    function testLiquidateDSCOwner() external {
        address owner = coin.owner();
        vm.expectRevert(DSCEngine.DSCEngine__InvalidUser.selector);
        engine.liquidate(owner);
    }
    function testLiquidateDSCEngine() external {
        vm.expectRevert(DSCEngine.DSCEngine__InvalidUser.selector);
        engine.liquidate(address(engine));
    }
    function testLiquidateSelf(address user) external {
        vm.assume(user != address(0));
        vm.assume(user != address(engine));
        assertEq(address(engine),coin.owner());

        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__InvalidUser.selector);
        engine.liquidate(user);
    }
    function testLiquidateDepositsZero(address user) external {
        vm.assume(user != address(0));
        vm.assume(user != address(engine));
        assertEq(address(engine),coin.owner());
        vm.assume(user != USER);    // USER is the liquidator who calls liquidate()

        vm.startPrank(user);
        assertEq(engine.getDepositsValueInUsd(),0);
        vm.stopPrank();

        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__DepositsCannotBeZero.selector);
        engine.liquidate(user);
        vm.stopPrank();
    }
    function testLiquidateMintsZero(
        address user,
        uint256 depositAmount,
        uint256 tokenSeed
        ) external skipIfNotOnAnvil 
    {
        vm.assume(user != address(0));
        vm.assume(user != address(engine));
        assertEq(address(engine),coin.owner());
        vm.assume(user != USER);    // USER is the liquidator who calls liquidate()
        uint256 maxDepositAmount = 1e9; // 1 billion collateral tokens
        depositAmount = bound(depositAmount,1,maxDepositAmount);
        address token;
        if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();} 
        else {(,token,,,,) = config.s_activeChainConfig();}

        ERC20Mock(token).mint(user,depositAmount);
        vm.startPrank(user);
        ERC20Mock(token).approve(address(engine),depositAmount);
        engine.depositCollateral(token,depositAmount);
        assert(engine.getDepositsValueInUsd() > 0);
        assertEq(engine.getMints(),0);
        vm.stopPrank();

        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MintsCannotBeZero.selector);
        engine.liquidate(user);
    }
    function testLiquidateUserDebtExceedsLiquidatorBalance(
        address liquidateTarget,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil
    {
        (address token,,,,,) = config.s_activeChainConfig();
        vm.assume(liquidateTarget != address(0));
        vm.assume(liquidateTarget != address(engine));
        assertEq(address(engine),coin.owner());
        vm.assume(liquidateTarget != USER); // USER is the liquidator who calls liquidate()
        uint256 maxDepositAmount = 1e9; // 1 billion collateral tokens
        depositAmount = bound(depositAmount,1,maxDepositAmount);
        uint256 threshold = engine.i_thresholdLimitPercent();
        uint256 fractional = engine.FRACTION_REMOVAL_MULTIPLIER();
        uint256 valueOfDeposits = engine.convertToUsd(token,depositAmount);
        uint256 maxMintAmount = valueOfDeposits * threshold / fractional;
        mintAmount = bound(mintAmount,1,maxMintAmount);

        ERC20Mock(token).mint(liquidateTarget,depositAmount);
        vm.startPrank(liquidateTarget);
        ERC20Mock(token).approve(address(engine),depositAmount);
        engine.depositCollateralMintDSC(token,depositAmount,mintAmount);
        vm.stopPrank();
        // note that USER is the liquidator calling liquidate()
        assertEq(coin.balanceOf(USER),0);

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(
                    keccak256("DSCEngine__UserDebtExceedsLiquidatorBalance(uint256,uint256)")),
            mintAmount,
            0));
        engine.liquidate(liquidateTarget);
    }
    function testLiquidateCannotBeLiquidated(
        address liquidateTarget,
        uint256 depositAmountWeth,
        uint256 depositAmountWbtc,
        uint256 mintAmount
        ) external skipIfNotOnAnvil
    {
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        vm.assume(liquidateTarget != address(0));
        vm.assume(liquidateTarget != address(engine));
        assertEq(address(engine),coin.owner());
        vm.assume(liquidateTarget != USER); // USER is the liquidator who calls liquidate()
        uint256 maxDepositAmount = 1e9; // 1 billion collateral tokens
        depositAmountWeth = bound(depositAmountWeth,1,maxDepositAmount);
        depositAmountWbtc = bound(depositAmountWbtc,1,maxDepositAmount-depositAmountWeth+1);
        uint256 threshold = engine.i_thresholdLimitPercent();
        uint256 fractional = engine.FRACTION_REMOVAL_MULTIPLIER();
        uint256 valueOfDeposits = engine.convertToUsd(weth,depositAmountWeth) 
            + engine.convertToUsd(wbtc,depositAmountWbtc);
        uint256 maxMintAmount = valueOfDeposits * threshold / fractional;
        mintAmount = bound(mintAmount,1,maxMintAmount);

        ERC20Mock(weth).mint(liquidateTarget,depositAmountWeth);
        ERC20Mock(wbtc).mint(liquidateTarget,depositAmountWbtc);
        vm.startPrank(liquidateTarget);
        ERC20Mock(weth).approve(address(engine),depositAmountWeth);
        ERC20Mock(wbtc).approve(address(engine),depositAmountWbtc);
        engine.depositCollateral(weth,depositAmountWeth);
        engine.depositCollateralMintDSC(wbtc,depositAmountWbtc,mintAmount);
        vm.stopPrank();
        // note that USER is the liquidator calling liquidate()
        vm.prank(address(engine));
        coin.mint(USER,mintAmount);
        assertEq(coin.balanceOf(USER),mintAmount);
        // no manipulation of collateral price here, so user liquidateTarget still within
        //  threshold limit and cannot be liquidated

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(
                    keccak256("DSCEngine__CannotBeLiquidated(address)")),
            liquidateTarget));
        engine.liquidate(liquidateTarget);
        vm.stopPrank();
    }
    function testLiquidateStateCorrectlyUpdated(
        uint256 depositAmountWeth,
        uint256 depositAmountWbtc,
        uint256 mintAmount,
        address liquidateTarget
        ) external skipIfNotOnAnvil
    {
        (
            address weth,
            address wbtc,
            address wethPriceFeed,
            address wbtcPriceFeed,,
        ) = config.s_activeChainConfig();
        {
            vm.assume(liquidateTarget != address(0));
            vm.assume(liquidateTarget != address(engine));
            assertEq(address(engine),coin.owner());
            vm.assume(liquidateTarget != USER); // USER is the liquidator who calls liquidate()
            uint256 maxDepositAmount = 1e9; // 1 billion collateral tokens
            depositAmountWeth = bound(depositAmountWeth,1,maxDepositAmount);
            depositAmountWbtc = bound(depositAmountWbtc,1,maxDepositAmount-depositAmountWeth+1);
            uint256 threshold = engine.i_thresholdLimitPercent();
            uint256 fractional = engine.FRACTION_REMOVAL_MULTIPLIER();
            uint256 valueOfDeposits = engine.convertToUsd(weth,depositAmountWeth) 
                + engine.convertToUsd(wbtc,depositAmountWbtc);
            uint256 maxMintAmount = valueOfDeposits * threshold / fractional;
            mintAmount = maxMintAmount;
            //mintAmount = bound(mintAmount,1,maxMintAmount);

            ERC20Mock(weth).mint(liquidateTarget,depositAmountWeth);
            ERC20Mock(wbtc).mint(liquidateTarget,depositAmountWbtc);
            vm.startPrank(liquidateTarget);
            ERC20Mock(weth).approve(address(engine),depositAmountWeth);
            ERC20Mock(wbtc).approve(address(engine),depositAmountWbtc);
            engine.depositCollateral(weth,depositAmountWeth);
            engine.depositCollateralMintDSC(wbtc,depositAmountWbtc,mintAmount);
            vm.stopPrank();
            // note that USER is the liquidator calling liquidate()
            vm.prank(address(engine));
            coin.mint(USER,mintAmount);
            vm.prank(USER);
            coin.approve(address(engine),mintAmount);
            assertEq(coin.balanceOf(USER),mintAmount);
        }

        // collect pre-liquidate values
        vm.startPrank(liquidateTarget);
        uint256 userMintsBefore = engine.getMints();
        uint256 userDepositWethBefore = engine.getDepositAmount(weth);
        uint256 userDepositWbtcBefore = engine.getDepositAmount(wbtc);
        // For the given number of deposited collaterals, after the price manipulation,
        //  the value of deposits is not the same as before. Have to calc the value of
        //  deposits from *after* the price manipulation has happened
        //uint256 userTotalDepositValueBefore = engine.getDepositsValueInUsd();
        vm.stopPrank();
        uint256 liquidatorWethBalanceBefore = ERC20Mock(weth).balanceOf(USER);
        uint256 liquidatorWbtcBalanceBefore = ERC20Mock(wbtc).balanceOf(USER);
        uint256 liquidatorDscBalanceBefore = coin.balanceOf(USER);
        uint256 dscTotalSupplyBefore = coin.totalSupply();

        // manipulate collateral price here, so user liquidateTarget breaches
        //  threshold limit and become liquidateable
        MockAggregatorV3(wethPriceFeed).useAltPriceTrue(200000000000);  // 1 wETH = 2000 USD
        MockAggregatorV3(wbtcPriceFeed).useAltPriceTrue(3400000000000); // 1 wBTC = 34000 USD
        // calc value of deposits here *after* the price manipulation, note that this is 
        //  still the before-liquidation value of deposits
        vm.prank(liquidateTarget);
        uint256 userTotalDepositValueBefore = engine.getDepositsValueInUsd();
        
        // liquidate and do the tests
        vm.startPrank(USER);
        // check for emit
        vm.expectEmit(true,true,true,false,address(engine));
        emit DSCEngine.Liquidated(liquidateTarget,userMintsBefore,userTotalDepositValueBefore);
        engine.liquidate(liquidateTarget);
        vm.stopPrank();
        vm.startPrank(liquidateTarget);
        // check that target mints/debt is zeroed
        assertEq(engine.getMints(),0);
        // check that all target deposits are zeroed
        assertEq(engine.getDepositAmount(weth),0);  // weth deposits
        assertEq(engine.getDepositAmount(wbtc),0);  // wbtc deposits
        assertEq(engine.getDepositsValueInUsd(),0); // total deposits value
        vm.stopPrank();
        // check that liquidator weth balance correctly increased
        assertEq(
            ERC20Mock(weth).balanceOf(USER),
            liquidatorWethBalanceBefore + userDepositWethBefore);
        // check that liquidator wbtc balance correctly increased
        assertEq(
            ERC20Mock(wbtc).balanceOf(USER),
            liquidatorWbtcBalanceBefore + userDepositWbtcBefore);
        // check that liquidator DSC balance correctly drawn down
        assertEq(coin.balanceOf(USER),liquidatorDscBalanceBefore - userMintsBefore);
        // check that DSC total supply correctly drawn down
        assertEq(coin.totalSupply(),dscTotalSupplyBefore - userMintsBefore);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getValueOfDepositsInUsd()
    ////////////////////////////////////////////////////////////////////
    function testValueOfDepositsIsCorrect(
        address user,
        uint256 randomDepositAmount
        ) external skipIfNotOnAnvil 
    {
        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        vm.assume(user != address(0));
        randomDepositAmount = bound(randomDepositAmount,1,100);
        uint256 arraySize = engine.getAllowedCollateralTokensArrayLength();
        for(uint256 i=0;i<arraySize;i++) {
            address token = engine.getAllowedCollateralTokens(i);
            // preparations needed:
            //  1. mint user enough collateral tokens for the deposit
            ERC20Mock(token).mint(user,randomDepositAmount);
            //  2. user to approve engine as spender with enough allowance for deposit
            vm.prank(user);
            ERC20Mock(token).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as user
            vm.prank(user);
            engine.depositCollateral(token,randomDepositAmount);
            console.log("Deposit #",i+1,": ",randomDepositAmount);
        }
        // perform the test:
        //  check that value of deposits is correct based on the deposits made
        uint256 returnValue = engine.exposegetValueOfDepositsInUsd(user);
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
    /*
    The function @dev notes detail why these zero address checks are not required.
    function test_redeemFromZeroAddress(address to,address token,uint256 amount) external {
        vm.expectRevert(DSCEngine.DSCEngine__AddressCannotBeZero.selector);
        engine.expose_redeemCollateral(address(0),to,token,amount);
    }
    function test_redeemToZeroAddress(address from,address token,uint256 amount) external {
        vm.assume(from != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__AddressCannotBeZero.selector);
        engine.expose_redeemCollateral(from,address(0),token,amount);
    }
    function test_redeemFromZeroAddressToZeroAddress(address token,uint256 amount) external {
        vm.expectRevert(DSCEngine.DSCEngine__AddressCannotBeZero.selector);
        engine.expose_redeemCollateral(address(0),address(0),token,amount);
    }
    */
    function test_redeemZeroAmount(address from,address to,address token) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(token != address(0));
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.expose_redeemCollateral(from,to,token,0);
    }
    function test_redeemZeroTokenAddress(address from,address to,uint256 amount) external {
        amount = bound(amount,1,type(uint256).max);
        //vm.assume(amount != 0);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.expose_redeemCollateral(from,to,address(0),amount);
    }
    function test_redeemNonAllowedToken(address from,address to,address token,uint256 amount) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        amount = bound(amount,1,type(uint256).max);
        //vm.assume(amount != 0);
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        vm.assume(token != weth);
        vm.assume(token != wbtc);
        vm.assume(token != address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                token));
        engine.expose_redeemCollateral(from,to,token,amount);
    }
    function test_redeemInsufficientBalance(
        uint256 tokenSeed,
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount
        ) external skipIfNotOnAnvil 
    {
        address token;
        if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
        else {(,token,,,,) = config.s_activeChainConfig();}
        uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
        depositAmount = bound(depositAmount,1,maxTokenBalance);
        redeemAmount = bound(redeemAmount,depositAmount+1,type(uint256).max);
        //vm.assume(redeemAmount > depositAmount);
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
    function test_redeemOutsideRedeemLimits(
        uint256 tokenSeed,
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        address token;
        if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
        else {(,token,,,,) = config.s_activeChainConfig();}
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
            * engine.i_thresholdLimitPercent() 
            / engine.FRACTION_REMOVAL_MULTIPLIER();
        mintAmount = bound(mintAmount,1,maxMintAmount);
        // fromuser mints (aka takes on debt from system)
        vm.prank(from);
        engine.mintDSC(mintAmount);
        // bound redeemAmount to be outside of redeem limit but within deposit amount
        uint256 maxSafeRedeemAmount = (maxMintAmount - mintAmount) 
                * engine.FRACTION_REMOVAL_MULTIPLIER() 
                / engine.i_thresholdLimitPercent();
        maxSafeRedeemAmount = engine.convertFromUsd(maxSafeRedeemAmount,token);
        redeemAmount = bound(
            redeemAmount,
            maxSafeRedeemAmount+1,
            depositAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__RequestedRedeemAmountBreachesUserRedeemLimit(address,address,uint256,uint256)")),
                from,
                token,
                redeemAmount,
                maxSafeRedeemAmount));
        engine.expose_redeemCollateral(from,to,token,redeemAmount);
    }
    function test_redeemStateCorrectlyUpdated(
        uint256 tokenSeed,
        address from,
        address to,
        uint256 redeemAmount,
        uint256 depositAmount,
        uint256 mintAmount
        ) external skipIfNotOnAnvil 
    {
        address token;
        {
            if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
            else {(,token,,,,) = config.s_activeChainConfig();}
            vm.assume(from != address(0));
            vm.assume(to != address(0));
            // these following 3 restrictions are NEEDED; never dreamed they would come up but yeah they do
            vm.assume(from != to);
            vm.assume(from != address(engine));
            vm.assume(to != address(engine));
            uint256 maxTokenBalance = 1e9; // 1 billion collateral tokens, arbitrary limit to prevent math overflow
            // bound deposit amount to within max token balance
            depositAmount = bound(depositAmount,1,maxTokenBalance);
            // mint collateral token to fromuser
            ERC20Mock(token).mint(from,depositAmount);
            // fromuser approves sufficient allowance to engine to perform the collateral token transfer during the deposit
            vm.startPrank(from);
            ERC20Mock(token).approve(address(engine),depositAmount);
            // fromuser deposits collateral into system
            engine.depositCollateral(token,depositAmount);
            vm.stopPrank();
            // calc max mint amount allowed by system given specific deposit amount
            uint256 threshold = engine.i_thresholdLimitPercent();
            uint256 fractional = engine.FRACTION_REMOVAL_MULTIPLIER();
            uint256 depositValue = engine.exposegetValueOfDepositsInUsd(from);
            uint256 maxMintAmount = depositValue * threshold / fractional;
            // bound mint amount to within max mint amount allowed
            mintAmount = bound(mintAmount,1,maxMintAmount);
            // fromuser mints (aka takes on debt from system)
            vm.prank(from);
            engine.mintDSC(mintAmount);
            // calc max redeem amount allowed by system given specific deposit amount 
            //  and specific mint amount
            //  (deposit value - max redeem value) * threshold / fractional = mint value
            //  max redeem value = deposit value - mint value * fractional / threshold
            //  max redeem amount = convertFromUsd(deposit value - mint value * fractional / threshold)
            uint256 maxSafeRedeemAmount = 
                engine.convertFromUsd(depositValue - mintAmount * fractional / threshold,token);
            // bound redeemAmount to be within max redeem amount allowed
            // restart run if maxSafeRedeemAmount < 1, as this will cause the bound
            //  to fail
            vm.assume(maxSafeRedeemAmount > 0);
            redeemAmount = bound(redeemAmount,1,maxSafeRedeemAmount);
        }

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

    ////////////////////////////////////////////////////////////////////
    // Unit tests for _burnDSC()
    ////////////////////////////////////////////////////////////////////
    /*
    The function @dev notes detail why these zero address checks are not required.
    function test_burnFromZeroAddress(address onBehalfOf,uint256 amount) external {
        vm.assume(onBehalfOf != address(0));
        vm.assume(amount != 0);
        vm.expectRevert(DSCEngine.DSCEngine__AddressCannotBeZero.selector);
        engine.expose_burnDSC(address(0),onBehalfOf,amount);
    }
    function test_burnOnBehalfOfZeroAddress(address dscFrom,uint256 amount) external {
        vm.assume(dscFrom != address(0));
        vm.assume(amount != 0);
        vm.expectRevert(DSCEngine.DSCEngine__AddressCannotBeZero.selector);
        engine.expose_burnDSC(dscFrom,address(0),amount);
    }
    function test_burnFromZeroAddressOnBehalfOfZeroAddress(uint256 amount) external {
        vm.assume(amount != 0);
        vm.expectRevert(DSCEngine.DSCEngine__AddressCannotBeZero.selector);
        engine.expose_burnDSC(address(0),address(0),amount);
    }
    */
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
        amountHeld = bound(amountHeld,1,type(uint256).max-1);
        burnAmount = bound(burnAmount,amountHeld+1,type(uint256).max);
        //vm.assume(amountHeld != 0);
        //vm.assume(burnAmount > amountHeld);
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
    function test_burnStateCorrectlyUpdated(
        uint256 tokenSeed,
        uint256 amountDSCTokensHeld,
        uint256 amountDSCMintDebt,
        uint256 burnAmount,
        uint256 depositAmount,
        address dscFrom,
        address onBehalfOf
        ) external skipIfNotOnAnvil 
    {
        address token;
        {
            if (tokenSeed % 2 == 0) {(token,,,,,) = config.s_activeChainConfig();}
            else {(,token,,,,) = config.s_activeChainConfig();}
            // setup
            //  1. mint enough DSC tokens for dscFrom to burn
            //  2. dscFrom approves sufficient allowance to engine for burn amount
            //  3. mint enough collateral tokens for onBehalfOf to deposit
            //  4. onBehalfOf deposits collaterals and mints DSC (aka take on debt) for 
            //      the liquidation burn
            vm.assume(dscFrom != address(0));
            vm.assume(onBehalfOf != address(0));
            vm.assume(dscFrom != onBehalfOf);
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
                * engine.FRACTION_REMOVAL_MULTIPLIER() 
                / engine.i_thresholdLimitPercent();
            uint256 maxDepositValueNeeded = 1 + amountDSCTokensHeld 
                * engine.FRACTION_REMOVAL_MULTIPLIER() 
                / engine.i_thresholdLimitPercent();
            uint256 minDepositAmountNeeded = 1 + engine.convertFromUsd(minDepositValueNeeded,token);
            uint256 maxDepositAmountNeeded = 1 + engine.convertFromUsd(maxDepositValueNeeded,token);
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
        }

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

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertFromTo()
    ////////////////////////////////////////////////////////////////////
    function testConvertFromZero(uint256 randomAmount) external {
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.convertFromTo(address(0),randomAmount,makeAddr("toToken"));
    }
    function testConvertToZero(uint256 randomAmount) external {
        address allowedToken = engine.getAllowedCollateralTokens(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.convertFromTo(allowedToken,randomAmount,address(0));
    }
    function testConvertFromZeroToZero(uint256 randomAmount) external {
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.convertFromTo(address(0),randomAmount,address(0));
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
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                    randomToken));
            engine.convertFromTo(
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
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                    randomToken));
            engine.convertFromTo(
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
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                    randomTokenA));
            engine.convertFromTo(
                randomTokenA,
                randomAmount,
                randomTokenB);
        }
    }
    function testConvertWethToWbtc(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wETH converted to ",engine.convertFromTo(weth,randomAmount,wbtc)," wBTC");
    }
    function testConvertWbtcToWeth(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wBTC converted to ",engine.convertFromTo(wbtc,randomAmount,weth)," wETH");
    }
    function testConvertWethToWbtcOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.convertFromTo(weth,randomAmount,wbtc);
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
        uint256 returnValue = engine.convertFromTo(wbtc,randomAmount,weth);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.convertFromUsd(randomAmount,address(0));
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
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                    randomToken));
            engine.convertFromUsd(randomAmount,randomToken);
        }
    }
    function testConvertToWETH(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e9);   // 1e9 == 1 billion USD, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," USD converted to ",engine.convertFromUsd(randomAmount,weth)," wEth");
    }
    function testConvertToWBTC(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e9);   // 1e9 == 1 billion USD, arbitrary limit to prevent calc overflow
        (,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," USD converted to ",engine.convertFromUsd(randomAmount,wbtc)," wBTC");
    }
    function testConvertToWETHOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,1e9);   // 1e9 == 1 billion USD, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.convertFromUsd(randomAmount,weth);
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
        uint256 returnValue = engine.convertFromUsd(randomAmount,wbtc);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.convertToUsd(address(0),randomAmount);
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
            vm.expectRevert(
                abi.encodeWithSelector(
                    bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                    randomToken));
            engine.convertToUsd(randomToken,randomAmount);
        }
    }
    function testConvertFromWETH(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wETH converted to ",engine.convertToUsd(weth,randomAmount)," USD");
    }
    function testConvertFromWBTC(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (,address wbtc,,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wBTC converted to ",engine.convertToUsd(wbtc,randomAmount)," USD");
    }
    function testConvertFromWETHOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,1e5);   // 1e5 == 100,000 tokens, arbitrary limit to prevent calc overflow
        (address weth,,,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.convertToUsd(weth,randomAmount);
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
        uint256 returnValue = engine.convertToUsd(wbtc,randomAmount);
        console.log(randomAmount," wBTC converted to ",returnValue," USD");
        assertEq(
            returnValue,
            vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD") * randomAmount 
                / (10**(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_BTC_USD"))));
    }

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
        index = bound(index,arrayLength,type(uint256).max);
        //vm.assume(index >= arrayLength);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
                address(0)));
        engine.getPriceFeed(address(0));
    }
    function testGetPriceFeedNonAllowedToken(address token) external {
        (address weth,address wbtc,,,,) = config.s_activeChainConfig();
        vm.assume(token != address(0));
        vm.assume(token != weth);
        vm.assume(token != wbtc);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("DSCEngine__InvalidToken(address)")),
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