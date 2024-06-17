// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 *  @title  Decentralized Stable Coin
 *  @notice This contract defines and implements the stablecoin as an ERC20 Ownable Burnable token
 *          to be managed by a separate DSCEngine contract.
 *          DSCEngine contract will be the owner for this stablecoin contract.
 *  @dev    Stablecoin characteristics:
 *              Collateral: Exogenous (ie: outside of system, specifically wETH & wBTC)
 *              Relative Stability: Anchored (ie: pegged to USD, via developer decree lol)
 *              Stability Mechanism: Decentralized Algorithmic (specifically via system-set threshold
 *                  ratio between collaterals value and mints value, and allowing other users to call
 *                  liquidate() on users who have breached the ratio)
 *          These characteristics are defined, implemented, and enforced by the DSCEngine contract.
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
    /**
     *  @notice constructor()
     *  @param  owner   Owner of this contract. Also the only account that can call the onlyOwner
     *                  functions.
     *  @dev    'DecentralizedStableCoin'   Name of this ERC20 token.
     *          'DSC'   Symbol of this ERC20 token.
     *  @dev    During deployment, this contract is deployed by an account that basically initiates
     *          and signs the transaction to run the deployment script DeployDecentralizedStableCoin.
     *          The script sets this account as the initial owner of this contract.
     *          When the DSCEngine (that manages/controls this contract) is then deployed, there must
     *          be an ownership transfer of this contract to the DSCEngine.
     *          This transfer must necessarily be performed by the same account that deployed this 
     *          contract in the 1st place.
     */
    constructor(address owner) ERC20("DecentralizedStableCoin","DSC") Ownable(owner) {}

    /**
     *  @notice burn()
     *          Burns an '_amount' of DSC tokens from the caller's balance.
     *          Can only be called by the owner of this contract.
     *          Only accepts non-zero '_amount'.
     *  @param  _amount Amount of DSC tokens to burn.
     *  @dev    This function overrides the burn() function which is defined as virtual in the 
     *          inherited ERC20Burnable contract.
     *  @dev    Reverts if:
     *              called by non-owners
     *              _amount is zero
     *              caller DSC balance is < _amount     (checked by ERC20's _update() function)
     */
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
        //  ERC20's _update(), which _burn() calls, only emits a transfer() event
        emit TokenBurned(msg.sender,_amount);
    }

    /**
     *  @notice mint()
     *          Mints an '_amount' of DSC tokens to the '_to' balance.
     *          Can only be called by the owner of this contract.
     *          Only accepts non-zero '_amount'.
     *  @param  _amount Amount of DSC tokens to mint.
     *  @dev    This function calls the _mint() function from the inherited ERC20 contract.
     *  @dev    Reverts if:
     *              called by non-owners
     *              _amount is zero
     *              caller '_to' is a zero address      (checked by ERC20's _update() function)
     */
    function mint(address _to, uint256 _amount) public onlyOwner moreThanZero(_amount) {
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
        //  ERC20's _update(), which _mint() calls, only emits a transfer() event
        emit TokenMinted(_to,_amount);
    }
}