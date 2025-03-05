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
    DeployDSC public deployer;
    ChangeOwner public changeOwner;

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

    function setUp() external {
    }
}