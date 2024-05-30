// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";

contract DecentralizedStableCoinTest is Test {
    /////////////////////////////////////////////////////////////////////////////////
    // All errors reverted by DecentralizedStableCoin contract and to be tested for
    /////////////////////////////////////////////////////////////////////////////////
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__InvalidAddress();
    /////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////////////
    // All events emitted by DecentralizedStableCoin contract and to be tested for
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /* State Variables */
    DecentralizedStableCoin public coin;

    /* Setup Functions */
    function setUp() external {
        DeployDecentralizedStableCoin deployer = new DeployDecentralizedStableCoin();
        coin = deployer.run();
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for constructor()
    ////////////////////////////////////////////////////////////////////
    function testInitialOwnerSetCorrectly() external view {
        assert(coin.owner() == address(this));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for transferOwnership()
    ////////////////////////////////////////////////////////////////////
    function testTransferOwnershipPerformedCorrectly() external {
        address NEWOWNER = makeAddr("new owner");
        coin.transferOwnership(NEWOWNER);
        assert(coin.owner() == NEWOWNER);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for mint()
    ////////////////////////////////////////////////////////////////////
    function testMintRequestFromNonOwner() external {
        address USER = makeAddr("user");
        uint256 mintAmount = 1e5;
        vm.prank(USER);
        vm.expectRevert();
        coin.mint(USER,mintAmount);
    }
    function testMintToZeroAddress() external {
        uint256 mintAmount = 1e5;   // 100,000 tokens
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__InvalidAddress.selector);
        coin.mint(address(0),mintAmount);
    }
    function testMintAmountZero() external {
        address USER = makeAddr("user");
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        coin.mint(USER,0);
    }
    function testTotalSupplyAfterMint() external {
        address USER = makeAddr("user");
        uint256 totalSupplyBeforeMint = coin.totalSupply();
        uint256 mintAmount = 1e9;   // 1 billion tokens
        console.log("totalSupplyBeforeMint: ",totalSupplyBeforeMint);
        console.log("mintAmount: ",mintAmount);
        coin.mint(USER,mintAmount);
        assert(coin.totalSupply() == mintAmount);
    }
    function testBalanceOfUserAfterMint() external {
        address USER = makeAddr("user");
        uint256 balanceOfUserBeforeMint = coin.balanceOf(USER);
        uint256 mintAmount = 1e9;   // 1 billion tokens
        console.log("balanceOfUserBeforeMint: ",balanceOfUserBeforeMint);
        console.log("mintAmount: ",mintAmount);
        coin.mint(USER,mintAmount);
        assert(coin.balanceOf(USER) == mintAmount);
    }
    ////////////////////////////////////////////////////////////////////
    // Unit tests for burn()
    ////////////////////////////////////////////////////////////////////
    function testBurnRequestFromNonOwner() external {
        address USER = makeAddr("user");
        uint256 burnAmount = 1e9;   // 1 billion tokens
        vm.prank(USER);
        vm.expectRevert();
        coin.burn(burnAmount);
    }
    function testBurnAmountZero() external {
        vm.prank(coin.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        coin.burn(0);
    }
    function testTotalSupplyAfterBurn() external {
        uint256 initialSupply = 2e9;    // 2 billion tokens
        coin.mint(coin.owner(),initialSupply);
        uint256 totalSupplyBeforeBurn = coin.totalSupply();
        uint256 burnAmount = 1000;
        console.log("totalSupplyBeforeBurn: ",totalSupplyBeforeBurn);
        console.log("burnAmount: ",burnAmount);
        coin.burn(burnAmount);
        assert(coin.totalSupply() == (totalSupplyBeforeBurn - burnAmount));
    }
    function testBurnAmountExceedsBalance() external {
        uint256 mintAmount = 1e9;   // 1 billion tokens
        coin.mint(coin.owner(),mintAmount);
        uint256 balanceOfUser = coin.balanceOf(coin.owner());
        console.log("balanceOfUser: ",balanceOfUser);
        uint256 burnAmount = 2e9;   // 2 billion tokens
        console.log("burnAmount: ",burnAmount);
        vm.prank(coin.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        coin.burn(burnAmount);
    }
}