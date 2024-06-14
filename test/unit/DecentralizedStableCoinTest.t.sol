// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";

contract DecentralizedStableCoinTest is Test {
    /* State Variables */
    DecentralizedStableCoin public coin;
    address public owner;

    /* Setup Functions */
    function setUp() external {
        DeployDecentralizedStableCoin deployer = new DeployDecentralizedStableCoin();
        coin = deployer.run();
        owner = coin.owner();
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for constructor()
    ////////////////////////////////////////////////////////////////////
    function testInitialOwnerSetCorrectly() external view {
        assert(owner == address(this));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for transferOwnership()
    ////////////////////////////////////////////////////////////////////
    function testTransferOwnershipRequestFromNonOwner(address requestor,address newOwner) external {
        vm.assume(requestor != address(0));
        vm.assume(requestor != owner);
        vm.assume(newOwner != address(0));

        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
            requestor));
        vm.prank(requestor);
        coin.transferOwnership(newOwner);
    }
    function testTransferOwnershipPerformedCorrectly(address newOwner) external {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != owner);

        address oldOwner = coin.owner();
        vm.prank(owner);
        coin.transferOwnership(newOwner);
        assertNotEq(coin.owner(),oldOwner);
        assertEq(coin.owner(),newOwner);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for mint()
    ////////////////////////////////////////////////////////////////////
    function testMintRequestFromNonOwner(address requestor,address to,uint256 mintAmount) external {
        vm.assume(requestor != address(0));
        vm.assume(requestor != owner);
        vm.assume(to != address(0));
        mintAmount = bound(mintAmount,1,type(uint256).max);
        vm.prank(requestor);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                requestor));
        coin.mint(to,mintAmount);
    }
    function testMintToZeroAddress(uint256 mintAmount) external {
        mintAmount = bound(mintAmount,1,type(uint256).max);
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("ERC20InvalidReceiver(address)")),
            address(0)));
        coin.mint(address(0),mintAmount);
    }
    function testMintAmountZero(address to) external {
        vm.assume(to != address(0));
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountCannotBeZero.selector);
        coin.mint(to,0);
    }
    function testMintStateCorrectlyUpdated(address to,uint256 mintAmount) external {
        vm.assume(to != address(0));
        mintAmount = bound(mintAmount,1,type(uint256).max);

        // collect all pre-mint values
        uint256 userBalanceBeforeMint = coin.balanceOf(to);
        uint256 coinTotalSupplyBeforeMint = coin.totalSupply();

        // perform mint and do the tests
        vm.startPrank(owner);
        //  check for emit
        vm.expectEmit(true,false,false,false,address(coin));
        emit DecentralizedStableCoin.TokenMinted(to,mintAmount);
        coin.mint(to,mintAmount);
        //  check user balance correctly increased
        assertEq(coin.balanceOf(to),userBalanceBeforeMint+mintAmount);
        //  check coin total supply correctly increased
        assertEq(coin.totalSupply(),coinTotalSupplyBeforeMint+mintAmount);
    }
    ////////////////////////////////////////////////////////////////////
    // Unit tests for burn()
    ////////////////////////////////////////////////////////////////////
    function testBurnRequestFromNonOwner(address requestor,uint256 burnAmount) external {
        vm.assume(requestor != address(0));
        vm.assume(requestor != coin.owner());
        burnAmount = bound(burnAmount,1,type(uint256).max);
        /*
        // using bounds to retrict fuzz inputs seems to result in more "valid" runs than using vm.assume()
        //vm.assume(burnAmount > 0);
        */
        vm.prank(requestor);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                requestor));
        coin.burn(burnAmount);
    }
    function testBurnAmountZero() external {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountCannotBeZero.selector);
        coin.burn(0);
    }
    function testBurnAmountExceedsBalance(uint256 burnAmount,uint256 mintAmount) external {
        burnAmount = bound(burnAmount,2,type(uint256).max);
        mintAmount = bound(mintAmount,1,burnAmount-1);
        /*
        // using bounds to retrict fuzz inputs seems to result in more "valid" runs than using vm.assume()
        vm.assume(burnAmount > 0);
        vm.assume(mintAmount < burnAmount);
        vm.assume(mintAmount > 0);
        */
        // only the owner can call mint()
        vm.prank(owner);
        // mint coins to owner
        coin.mint(owner,mintAmount);
        // call burn() and check for revert
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")),
            owner,
            coin.balanceOf(owner),
            burnAmount));
        // only the owner can call burn()
        vm.prank(owner);
        coin.burn(burnAmount);
    }
    function testBurnStateCorrectlyUpdated(uint256 burnAmount,uint256 mintAmount) external {
        mintAmount = bound(mintAmount,1,type(uint256).max);
        burnAmount = bound(burnAmount,1,mintAmount);
        vm.prank(owner);
        coin.mint(owner,mintAmount);

        // collect all pre-burn values
        uint256 userBalanceBeforeBurn = coin.balanceOf(owner);
        uint256 coinTotalSupplyBeforeBurn = coin.totalSupply();
        // perform the burn and do the tests
        vm.startPrank(owner);
        //  check for emit
        vm.expectEmit(true,true,false,false,address(coin));
        emit DecentralizedStableCoin.TokenBurned(owner,burnAmount);
        coin.burn(burnAmount);
        vm.stopPrank();
        //  check owner balance drawn down correctly
        assertEq(coin.balanceOf(owner),userBalanceBeforeBurn-burnAmount);
        //  check token total supply drawn down correctly
        assertEq(coin.totalSupply(),coinTotalSupplyBeforeBurn-burnAmount);
    }
}