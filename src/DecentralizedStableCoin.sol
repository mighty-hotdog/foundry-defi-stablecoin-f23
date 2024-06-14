// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 *  @title  Decentralized Stable Coin
 *  @notice This contract defines and implements the stablecoin as an ERC20 token to be managed by 
 *          a separate DSCEngine contract.
 *          For this to happen, DSCEngine contract will be the owner for this stablecoin contract.
 *  @dev    Stablecoin characteristics:
 *              Collateral: Exogenous (specifically wETH & wBTC)
 *              Relative Stability: Anchored (ie: pegged to USD)
 *              Stability Mechanism: Decentralized Algorithmic
 *          These characteristics will be defined, implemented, and enforced by the DSCEngine contract.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    /* Errors */
    error DecentralizedStableCoin__AmountCannotBeZero();

    /* Events */
    event TokenBurned(address indexed fromUser,uint256 indexed amount);
    event TokenMinted(address indexed toUser,uint256 indexed amount);

    /* Modifiers */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DecentralizedStableCoin__AmountCannotBeZero();
        }
        _;
    }

    /* Functions */
    constructor(address owner) ERC20("DecentralizedStableCoin","DSC") Ownable(owner) {}

    // override the burn() function which is a virtual function in the inherited ERC20Burnable contract
    function burn(uint256 _amount) public override onlyOwner moreThanZero(_amount) {
        /*
        // ERC20's _update() already checks for insufficient balance and throws an appropriate revert
        uint256 balance = balanceOf(msg.sender);
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        */
        // The "super" keyword references a contract 1 level higher in the inheritance hierarchy.
        //  ie: in this case, this keyword instructs the EVM to call the burn() function defined in the 
        //  ERC20Burnable contract.
        super.burn(_amount);
        // this TokenBurned() event emit is needed. ERC20Burnable's burn() and ERC20's _burn() don't 
        //  emit any burn events.
        //  ERC20's _update() (which _burn() calls) only emits a transfer() event
        emit TokenBurned(msg.sender,_amount);
    }

    // New definition of the mint() function, as there is no mint() virtual function defined in any of 
    // the inherited contracts.
    function mint(address _to, uint256 _amount) public onlyOwner moreThanZero(_amount) returns (bool) {
        /*
        // ERC20's _mint() already checks for zero address receiver and throws an appropriate revert
        if (_to == address(0)) {
            revert DecentralizedStableCoin__ReceiverAddressCannotBeZero();
        }
        */
        // The _mint() function (non-virtual, internal) is defined in the ERC20 contract, which is 
        //  inherited by this contract as part of the ERC20Burnable contract.
        _mint(_to,_amount);
        // this TokenMinted() event emit is needed. ERC20's _mint() doesn't emit any mint events.
        //  ERC20's _update() (which _mint() calls) only emits a transfer() event
        emit TokenMinted(_to,_amount);
        return true;
    }
}