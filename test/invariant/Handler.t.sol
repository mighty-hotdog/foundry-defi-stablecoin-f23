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
    //DeployDSC public deployer;
    //ChangeOwner public changeOwner;

    address[] public actors;
    address private currentActor;
    uint256 public totalCollateralValue;
    uint256 public totalDebtValue;

    modifier useActor(uint96 actorSeed) {
        if (actors.length == 0) {
            return;
        }
        currentActor = actors[bound(actorSeed,0,actors.length-1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(address _coin, address _engine) {
        // setup contract addresses for use in tests
        coin = DecentralizedStableCoin(_coin);
        engine = DSCEngine(_engine);

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
        // prep to call engine.depositCollateral():
        // 1. caller has enough collateral
        // 2. engine has needed approval to spend caller's collateral

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

        // if not reverted, update total collateral value
        totalCollateralValue += engine.convertToUsd(collateral,amount);

        // add address to list of depositors
        actors.push(depositor);
    }
    function mintDSC(uint96 actorSeed,uint256 amount) external useActor(actorSeed) {
        // prep to call engine.mintDSC():
        // 1. caller has deposited some collaterals (both wETH and wBTC) and minted some DSC
        // 2. bound amount to within allowed mint amount given (1)

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
        // prep to call engine.redeemCollateral():
        // 1. caller has deposited some collateral (both wETH and wBTC) and minted some DSC
        // 2. bound amount to within allowed redeem amount given (1)

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
        console.log("currentActor Collateral Balance = ",engine.getDepositAmount(collateral));
        engine.redeemCollateral(collateral,amount);

        // if not reverted, update total collateral value
        totalCollateralValue -= engine.convertToUsd(collateral,amount);
    }
    function burnDSC(uint96 actorSeed,uint256 amount) external useActor(actorSeed) {
        // prep to call engine.burnDSC():
        // 1. caller has minted some DSC

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
    function liquidate(uint96 actorSeed,address userToLiquidate) external useActor(actorSeed) {}
}