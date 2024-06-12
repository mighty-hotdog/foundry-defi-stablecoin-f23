// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";

contract DecentralizedStableCoinTest is Test {
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
    function testTransferOwnershipRequestFromNonOwner() external {
        address NOTOWNER = makeAddr("not owner");
        address NEWOWNER = makeAddr("newowner");
        // set up expectRevert() to take an error with parameters by:
        //  1. creating the selector
        // no need for the Ownable prefix, not sure why..
        //bytes4 selector = bytes4(keccak256("Ownable.OwnableUnauthorizedAccount(address)"));
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        //  2. abi encode selector with expected parameters
        bytes memory expectedError = abi.encodeWithSelector(selector,NOTOWNER);
        vm.prank(NOTOWNER);
        //  3. apply in vm.expectRevert() like other errors
        vm.expectRevert(expectedError);
        coin.transferOwnership(NEWOWNER);
    }
    function testTransferOwnershipPerformedCorrectly() external {
        address NEWOWNER = makeAddr("new owner");
        assert(coin.owner() != NEWOWNER);
        vm.prank(coin.owner());
        coin.transferOwnership(NEWOWNER);
        assert(coin.owner() == NEWOWNER);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for mint()
    ////////////////////////////////////////////////////////////////////
    function testMintRequestFromNonOwner() external {
        address NOTOWNER = makeAddr("not owner");
        address USER = makeAddr("user");
        uint256 mintAmount = 1e5;
        vm.prank(NOTOWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                NOTOWNER));
        coin.mint(USER,mintAmount);
    }
    function testMintToZeroAddress() external {
        uint256 mintAmount = 1e5;   // 100,000 tokens
        vm.prank(coin.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__ReceiverAddressCannotBeZero.selector);
        coin.mint(address(0),mintAmount);
    }
    function testMintAmountZero() external {
        address USER = makeAddr("user");
        vm.prank(coin.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        coin.mint(USER,0);
    }
    function testTotalSupplyAfterMint(uint256 mintAmount) external {
        mintAmount = bound(mintAmount, 1, type(uint256).max);
        address USER = makeAddr("user");
        assertEq(coin.totalSupply(),0);
        vm.prank(coin.owner());
        coin.mint(USER,mintAmount);
        assertEq(coin.totalSupply(),mintAmount);
    }
    function testBalanceOfUserAfterMint(uint256 mintAmount) external {
        mintAmount = bound(mintAmount, 1, type(uint256).max);
        address USER = makeAddr("user");
        assertEq(coin.balanceOf(USER),0);
        vm.prank(coin.owner());
        coin.mint(USER,mintAmount);
        assertEq(coin.balanceOf(USER),mintAmount);
    }
    function testExpectEmitTokenMinted(uint256 mintAmount) external {
        mintAmount = bound(mintAmount, 1, type(uint256).max);
        address USER = makeAddr("user");
        vm.expectEmit(true,true,false,false,address(coin));
        emit DecentralizedStableCoin.TokenMinted(USER,mintAmount);
        vm.prank(coin.owner());
        coin.mint(USER,mintAmount);
    }
    ////////////////////////////////////////////////////////////////////
    // Unit tests for burn()
    ////////////////////////////////////////////////////////////////////
    function testBurnRequestFromNonOwner() external {
        address NOTOWNER = makeAddr("not owner");
        uint256 burnAmount = 1e9;   // 1 billion tokens
        vm.prank(NOTOWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                NOTOWNER));
        coin.burn(burnAmount);
    }
    function testBurnAmountZero() external {
        vm.prank(coin.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        coin.burn(0);
    }
    function testTotalSupplyAfterBurn(uint256 initialSupply,uint256 burnAmount) external {
        initialSupply = bound(initialSupply,1,type(uint256).max);
        burnAmount = bound(burnAmount,1,initialSupply);
        vm.prank(coin.owner());
        coin.mint(coin.owner(),initialSupply);
        uint256 totalSupplyBeforeBurn = coin.totalSupply();
        vm.prank(coin.owner());
        coin.burn(burnAmount);
        assertEq(coin.totalSupply(),(totalSupplyBeforeBurn - burnAmount));
    }
    function testBalanceOfOwnerAfterBurn(uint256 initialSupply,uint256 burnAmount) external {
        initialSupply = bound(initialSupply,1,type(uint256).max);
        burnAmount = bound(burnAmount,1,initialSupply);
        vm.prank(coin.owner());
        coin.mint(coin.owner(),initialSupply);
        uint256 balanceOfOwnerBeforeBurn = coin.balanceOf(coin.owner());
        vm.prank(coin.owner());
        coin.burn(burnAmount);
        assertEq(coin.balanceOf(coin.owner()),(balanceOfOwnerBeforeBurn - burnAmount));
    }
    function testBurnAmountExceedsBalance() external {
        uint256 mintAmount = 1e9;   // 1 billion tokens
        vm.prank(coin.owner());
        coin.mint(coin.owner(),mintAmount);
        uint256 balanceOfUser = coin.balanceOf(coin.owner());
        console.log("balanceOfUser: ",balanceOfUser);
        uint256 burnAmount = 2e9;   // 2 billion tokens
        console.log("burnAmount: ",burnAmount);
        vm.prank(coin.owner());
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        coin.burn(burnAmount);
    }
    function testExpectEmitTokenBurned(uint256 initialSupply,uint256 burnAmount) external {
        initialSupply = bound(initialSupply,1,type(uint256).max);
        burnAmount = bound(burnAmount,1,initialSupply);
        vm.prank(coin.owner());
        coin.mint(coin.owner(),initialSupply);
        vm.expectEmit(true,true,false,false,address(coin));
        emit DecentralizedStableCoin.TokenBurned(coin.owner(),burnAmount);
        vm.prank(coin.owner());
        coin.burn(burnAmount);
    }
}