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
    event CollateralDeposited(address indexed user,address indexed collateralTokenAddress,uint256 indexed amount);
    event DSCMinted(address indexed toUser,uint256 indexed amount);
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
    // It is already performed in the DeployDSCEngineTest test script under:
    //  1. testDeployInSepoliaWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //  2. testDeployInMainnetWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //  3. testDeployInAnvilWithCorrectAllowedCollateralTokensAndPriceFeeds()
    //function testCorrectAllowedCollateralTokensAndPriceFeeds() external {}

    ////////////////////////////////////////////////////////////////////
    // Unit tests for depositCollateral()
    ////////////////////////////////////////////////////////////////////
    function testDepositTokenWithZeroAddress(uint256 randomDepositAmount) external {
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokenAddressCannotBeZero.selector);
        engine.depositCollateral(address(0), randomDepositAmount);
    }
    function testDepositNonAllowedTokens(address randomTokenAddress,uint256 randomDepositAmount) external {
        vm.assume(randomTokenAddress != address(0));
        randomDepositAmount = bound(randomDepositAmount,1,type(uint256).max);
        (uint256 arraySize,address[] memory arrayTokens) = engine.getAllowedCollateralTokensArray();
        bool isNonAllowedToken = true;
        for(uint256 i=0;i<arraySize;i++) {
            if (randomTokenAddress == arrayTokens[i]) {
                isNonAllowedToken = false;
                break;
            }
        }
        if (isNonAllowedToken) {
            // if deposit non-allowed token, revert
            vm.prank(USER);
            vm.expectRevert();
            engine.depositCollateral(randomTokenAddress, randomDepositAmount);
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
        (uint256 arraySize,address[] memory arrayTokens) = engine.getAllowedCollateralTokensArray();
        for(uint256 i=0;i<arraySize;i++) {
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(arrayTokens[i]).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(arrayTokens[i]).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.prank(USER);
            engine.depositCollateral(arrayTokens[i], randomDepositAmount);
        }
    }
    function testDepositZeroAmount() external {
        (uint256 arraySize,address[] memory arrayTokens) = engine.getAllowedCollateralTokensArray();
        for(uint256 i=0;i<arraySize;i++) {
            vm.prank(USER);
            vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
            engine.depositCollateral(arrayTokens[i], 0);
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
        (uint256 arraySize,address[] memory arrayTokens) = engine.getAllowedCollateralTokensArray();
        for(uint256 i=0;i<arraySize;i++) {
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(arrayTokens[i]).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(arrayTokens[i]).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.prank(USER);
            engine.depositCollateral(arrayTokens[i], randomDepositAmount);
            // do the check
            assert(
                // check that engine deposit records are correct
                (engine.getDepositHeld(USER, arrayTokens[i]) == randomDepositAmount) &&
                // check that user balance is correct
                (ERC20Mock(arrayTokens[i]).balanceOf(USER) == 0) &&
                // check that engine balance is correct
                (ERC20Mock(arrayTokens[i]).balanceOf(address(engine)) == randomDepositAmount)
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
        (uint256 arraySize,address[] memory arrayTokens) = engine.getAllowedCollateralTokensArray();
        for(uint256 i=0;i<arraySize;i++) {
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(arrayTokens[i]).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(arrayTokens[i]).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.expectEmit(true, true, true, false, address(engine));
            emit CollateralDeposited(USER,arrayTokens[i],randomDepositAmount);
            vm.prank(USER);
            engine.depositCollateral(arrayTokens[i], randomDepositAmount);
        }
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for mintDSC()
    ////////////////////////////////////////////////////////////////////
    function testMintZeroAmount() external {
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        engine.mintDSC(0);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for convertToValueInUsd()
    ////////////////////////////////////////////////////////////////////
    function testConvertWETH(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,100);
        (address weth,,,) = config.s_activeChainConfig();
        console.log(randomAmount," wETH is ",engine.exposeconvertToValueInUsd(weth,randomAmount),"USD");
    }
    function testConvertWBTC(uint256 randomAmount) external view {
        randomAmount = bound(randomAmount,0,100);
        (,address wbtc,,) = config.s_activeChainConfig();
        console.log(randomAmount," wBTC is ",engine.exposeconvertToValueInUsd(wbtc,randomAmount),"USD");
    }
    function testConvertWETHOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,100);
        (address weth,,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertToValueInUsd(weth,randomAmount);
        console.log(randomAmount," wETH is ",returnValue,"USD");
        assertEq(returnValue,vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD")*randomAmount/1e8);
    }
    function testConvertWBTCOnAnvil(uint256 randomAmount) external view skipIfNotOnAnvil {
        // This test performs an assertEq() comparing function return vs mock datafeed answer set in the 
        //  .env, hence it can only pass when referencing mock data feeds deployed in Anvil. Therefore 
        //  skip if on any chain other than Anvil.
        randomAmount = bound(randomAmount,0,100);
        (,address wbtc,,) = config.s_activeChainConfig();
        uint256 returnValue = engine.exposeconvertToValueInUsd(wbtc,randomAmount);
        console.log(randomAmount," wBTC is ",returnValue,"USD");
        assertEq(returnValue,vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD")*randomAmount/1e8);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getValueOfDepositsHeldInUsd()
    ////////////////////////////////////////////////////////////////////
    function testValueOfDepositsIsCorrect(uint256 randomDepositAmount) external skipIfNotOnAnvil {
        // this test calls ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
        //  contracts on the Sepolia or Mainnet, hence this call doesn't work on those chains 
        //  and we have no way to mint the user some WETH/WBTC for the deposit call.
        //  So run this test only on Anvil where the Mock ERC20 token deployed does implement
        //  mint(). Skip this test on any other chain.
        randomDepositAmount = bound(randomDepositAmount,1,100);
        (uint256 arraySize,address[] memory arrayTokens) = engine.getAllowedCollateralTokensArray();
        for(uint256 i=0;i<arraySize;i++) {
            // preparations needed:
            //  1. mint USER enough collateral tokens for the deposit
            ERC20Mock(arrayTokens[i]).mint(USER,randomDepositAmount);
            //  2. USER to approve engine as spender with enough allowance for deposit
            vm.prank(USER);
            ERC20Mock(arrayTokens[i]).approve(address(engine),randomDepositAmount);
            //  3. perform the actual deposit call as USER
            vm.prank(USER);
            engine.depositCollateral(arrayTokens[i], randomDepositAmount);
            console.log("Deposit #",i+1,": ",randomDepositAmount);
        }
        uint256 returnValue = engine.exposegetValueOfDepositsHeldInUsd(USER);
        console.log("Value of Deposits: ",returnValue,"USD");
        assertEq(
            returnValue,
            (
                (vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD")*randomDepositAmount/1e8) + 
                (vm.envUint("CHAINLINK_MOCK_PRICE_FEED_ANSWER_BTC_USD")*randomDepositAmount/1e8)
            )
        );
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getValueOfMintsHeldInUsd()
    ////////////////////////////////////////////////////////////////////
    function testValueOfMintsIsCorrect() external {}
}