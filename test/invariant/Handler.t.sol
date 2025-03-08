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

contract Handler is Test {
    DecentralizedStableCoin public coin;
    DSCEngine public engine;
    ChainConfigurator public config;

    address[] public actors;
    address private currentActor;
    uint256 public totalCollateralValue;
    uint256 public totalDebtValue;
    uint256 public totalWethDeposit;
    uint256 public totalWbtcDeposit;

    modifier useActor(uint96 actorSeed) {
        if (actors.length == 0) {
            return;
        }
        currentActor = actors[bound(actorSeed,0,actors.length-1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(address _coin, address _engine, address _config) {
        // setup contract addresses for use in tests
        coin = DecentralizedStableCoin(_coin);
        engine = DSCEngine(_engine);
        config = ChainConfigurator(_config);

        // check contract addresses are valid
        if ((bytes32(bytes(coin.name())) != "DecentralizedStableCoin") || (bytes32(bytes(coin.symbol())) != "DSC")) {
            revert("Invalid DecentralizedStableCoin address");
        }
        if (engine.i_dscToken() != address(coin)) {
            revert("Invalid DSCEngine address");
        }
    }

    function setUp() external {}

    // The following set of tests: depositCollateral(), mintDSC(), redeenCollateral(), burnDSC(), liquidate()
    //  all rely on ERC20Mock.mint() which is not implemented in the real WETH and WBTC 
    //  contracts on the Sepolia or Mainnet, hence these tests won't work on those chains.
    //  So run these tests only on Anvil where the Mock ERC20 token is deployed.
    //  Skip these tests on any other chain.

    function depositCollateral(uint96 tokenSeed,address depositor,uint256 amount) external {
        // sanity check for depositor and amount
        vm.assume(depositor != address(0));
        vm.assume(depositor != address(engine));
        amount = bound(amount,1,type(uint96).max);

        // determine the random collateral token to deposit
        address collateral = engine.getAllowedCollateralTokens(tokenSeed % 2);
        // mint the deposit amount to depositor
        ERC20Mock(collateral).mint(depositor,amount);
        // approve engine as spender
        vm.startPrank(depositor);
        ERC20Mock(collateral).approve(address(engine),amount);
        // perform the actual deposit
        engine.depositCollateral(collateral,amount);
        vm.stopPrank();

        // if not reverted, update total collateral deposit
        if (tokenSeed % 2 == 0) {
            totalWethDeposit += amount;
        } else {
            totalWbtcDeposit += amount;
        }
        // update total collateral value
        totalCollateralValue = totalWethDeposit * engine.convertToUsd(engine.getAllowedCollateralTokens(0),1) +
                               totalWbtcDeposit * engine.convertToUsd(engine.getAllowedCollateralTokens(1),1);

        // add address to list of depositors
        actors.push(depositor);
    }
    function mintDSC(uint96 actorSeed,uint256 amount) external useActor(actorSeed) {
        // if user has 0 deposit, skip test
        uint256 currentDepositValue = engine.getDepositsValueInUsd();   // obtain deposits value for user = currentActor
        if (currentDepositValue == 0) {
            return;
        }
        // if max mint value is 0, skip test
        uint256 currentMintValue = engine.getMintsValueInUsd();   // obtain mints value for user = currentActor
        uint256 maxMintAllowed = 
            currentDepositValue * engine.i_thresholdLimitPercent() / engine.FRACTION_REMOVAL_MULTIPLIER() - currentMintValue;
        if (maxMintAllowed == 0) {
            return;
        }
        // bound amount to max mint amount allowed
        amount = bound(amount,1,maxMintAllowed);
        // perform mint for user = currentActor
        engine.mintDSC(amount);

        // if not reverted, update total debt value
        totalDebtValue += amount;
    }
    function redeemCollateral(uint96 actorSeed,uint96 tokenSeed,uint256 amount) external useActor(actorSeed) {
        // if user has 0 deposit of this collateral, skip test
        address collateral = engine.getAllowedCollateralTokens(tokenSeed % 2);
        uint256 collateralBalance = engine.getDepositAmount(collateral);    // obtain collateral balance for user = currentActor
        if (collateralBalance == 0) {
            return;
        }
        // if max redeemable value is 0, skip test
        uint256 currentDepositValue = engine.getDepositsValueInUsd();   // obtain deposits value for user = currentActor
        uint256 currentMintValue = engine.getMintsValueInUsd();   // obtain mints value for user = currentActor
        uint256 maxRedeemableValue = 
            currentDepositValue - currentMintValue * engine.FRACTION_REMOVAL_MULTIPLIER() / engine.i_thresholdLimitPercent();
        if (maxRedeemableValue == 0) {
            return;
        }
        // max redeemable amount is the smaller of collateral balance and threshold limit calculation
        uint256 maxCollateralRedeemable = maxRedeemableValue / engine.convertToUsd(collateral,1);
        if (maxCollateralRedeemable > collateralBalance) {
            maxCollateralRedeemable = collateralBalance;
        }
        // if final max redeemable amount is 0, skip test
        if (maxCollateralRedeemable == 0) {
            return;
        }
        // bound redeem amount to within max redeem amount allowed
        amount = bound(amount,1,maxCollateralRedeemable);
        // perform redeem for user = currentActor
        engine.redeemCollateral(collateral,amount);

        // if not reverted, update total collateral deposit
        if (tokenSeed % 2 == 0) {
            totalWethDeposit -= amount;
        } else {
            totalWbtcDeposit -= amount;
        }
        // update total collateral value
        totalCollateralValue = totalWethDeposit * engine.convertToUsd(engine.getAllowedCollateralTokens(0),1) +
                               totalWbtcDeposit * engine.convertToUsd(engine.getAllowedCollateralTokens(1),1);
    }
    function burnDSC(uint96 actorSeed,uint256 amount) external useActor(actorSeed) {
        // if user has 0 mints, skip test
        uint256 currentMintValue = engine.getMints();   // obtain mints for user = currentActor
        if (currentMintValue == 0) {
            return;
        }
        // bound amount to within current total mint by user
        amount = bound(amount,1,currentMintValue);
        // user = currentActor approves engine as spender w/ allowance amount
        coin.approve(address(engine),amount);
        // perform burn for user = currentActor
        engine.burnDSC(amount);

        // if not reverted, update total debt value
        totalDebtValue -= amount;
    }
    function liquidate(uint96 actorSeedToLiquidate,address liquidator) external /*useActor(actorSeedToLiquidate)*/ {
        // prepare to call liquidate()
        // 1. find liquidatee w/ non-zero debt
        // 2. manipulate collateral price(s) so liquidatee breaches threshold limit
        // 3. mint enuff DSC to liquidator to pay off liquidatee debt

        // can't use useActor() modifier because there are more than 1 actor in this test
        // gotta go "manual"
        if (actors.length == 0) {
            return;
        }
        currentActor = actors[bound(actorSeedToLiquidate,0,actors.length-1)];
        // sanity check for liquidator
        vm.assume(liquidator != address(0));
        vm.assume(liquidator != coin.owner());
        vm.assume(liquidator != address(engine));
        vm.assume(liquidator != currentActor);
        // if liquidatee = currentActor has 0 debt, skip test
        vm.prank(currentActor);
        uint256 liquidateeDebt = engine.getMints();
        if (liquidateeDebt == 0) {
            return;
        }
        // obtain liquidatee's collateral deposits and total deposit
        vm.startPrank(currentActor);
        uint256 liquidateeWethDeposit = engine.getDepositAmount(engine.getAllowedCollateralTokens(0));
        uint256 liquidateeWbtcDeposit = engine.getDepositAmount(engine.getAllowedCollateralTokens(1));
        uint256 liquidateeTotalDepositValue = engine.getDepositsValueInUsd();
        vm.stopPrank();
        // if liquidatee debt is less than 1/4 of total deposit value, skip test
        if (liquidateeDebt < liquidateeTotalDepositValue / 4) {
            return;
        }
        // mint enuff DSC to liquidator to pay off liquidatee debt
        vm.prank(address(engine));
        coin.mint(liquidator,liquidateeDebt);
        // liquidator approves engine as spender w/ allowance value
        vm.prank(liquidator);
        coin.approve(address(engine),liquidateeDebt);
        // manipulate collateral price(s) so liquidatee breaches threshold limit
        (
            ,,
            address wethPriceFeed,
            address wbtcPriceFeed,,
        ) = config.s_activeChainConfig();
        MockAggregatorV3(wethPriceFeed).useAltPriceTrue(200000000000);  // 1 wETH = 2000 USD
        MockAggregatorV3(wbtcPriceFeed).useAltPriceTrue(3400000000000); // 1 wBTC = 34000 USD
        // perform liquidate()
        vm.prank(liquidator);
        engine.liquidate(currentActor);

        // if not reverted, update total debt value and total collateral deposit
        totalDebtValue -= liquidateeDebt;
        totalWethDeposit -= liquidateeWethDeposit;
        totalWbtcDeposit -= liquidateeWbtcDeposit;
        // update total collateral value
        totalCollateralValue = totalWethDeposit * engine.convertToUsd(engine.getAllowedCollateralTokens(0),1) +
                               totalWbtcDeposit * engine.convertToUsd(engine.getAllowedCollateralTokens(1),1);
        // reset price manipulation to OFF
        MockAggregatorV3(wethPriceFeed).useAltPriceFalse();
        MockAggregatorV3(wbtcPriceFeed).useAltPriceFalse();
    }
}