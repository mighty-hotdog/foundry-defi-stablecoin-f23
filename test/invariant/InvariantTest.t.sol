// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {StdInvariant,Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ChainConfigurator} from "../../script/ChainConfigurator.s.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {ChangeOwner} from "../../script/ChangeOwner.s.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    DecentralizedStableCoin public coin;
    DSCEngine public engine;
    ChainConfigurator public config;
    DeployDSC public deployer;
    ChangeOwner public changeOwner;
    Handler public handler;
    
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

        handler = new Handler(address(coin),address(engine));
        targetContract(address(handler));
    }

    function invariant_noGetterShouldRevert(/*uint256 index, address token*/) external view {
        engine.getAllowedCollateralTokensArrayLength();
        engine.i_dscToken();
        engine.i_thresholdLimitPercent();
        engine.FRACTION_REMOVAL_MULTIPLIER();
        //uint256 arrayLength = engine.getAllowedCollateralTokensArrayLength();
        //engine.getAllowedCollateralTokens(index % arrayLength);
        //engine.getPriceFeed(token);
    }
    function invariant_totalCollateralGTTotalDebt() external view {
        // total value of deposited collateral in system must always be greater than total value of debt
        console.log("totalCollateralValue = ",handler.totalCollateralValue());
        console.log("totalDebtValue = ",handler.totalDebtValue());
        assert(handler.totalCollateralValue() >= handler.totalDebtValue());
    }
}