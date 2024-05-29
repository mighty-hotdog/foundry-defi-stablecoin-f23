// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 *  @title  DSCEngine
 *  @notice This contract defines and implements the logic to manage the Decentralized Stablecoin token.
 *  @dev    This contract is the Owner of the DecentralizedStableCoin contract.
 *          Stablecoin characteristics to be implemented and enforced by this contract:
 *              Collateral: Exogenous (specifically wETH & wBTC)
 *              Relative Stability: Anchored (ie: pegged to USD)
 *              Stability Mechanism: Decentralized Algorithmic
 *          Makes use of Chainlink Price Feeds.
 */
contract DSCEngine is ReentrancyGuard {
    /* Errors */
    error DSCEngine__TokenNotAllowed(address tokenAddress);
    error DSCEngine__InvalidAmount();
    error DSCEngine__ConstructorInputParamsMismatch(uint256 lengthOfCollateralAddressesArray,uint256 lengthOfPriceFeedsArray);
    error DSCEngine__CollateralTokenAddressCannotBeZero();
    error DSCEngine__PriceFeedAddressCannotBeZero();
    error DSCEngine__TokenAddressCannotBeZero();
    error DSCEngine__TransferFailed(address from,address to,address collateralTokenAddress,uint256 amount);

    /* State Variables */
    mapping(address allowedTokenAddress => address tokenPriceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address collateralTokenAddress => uint256 collateralAmountDeposited)) private s_userToCollateralDeposited;
    address private immutable i_dscToken;

    /* Events */
    event CollateralDeposited(address indexed user,address indexed collateralTokenAddress,uint256 indexed amount);

    /* modifiers */
    modifier onlyAllowedTokens(address collateralAddress) {
        if (collateralAddress == address(0)) {
            revert DSCEngine__TokenAddressCannotBeZero();
        }
        if (s_tokenToPriceFeed[collateralAddress] == address(0)) {
            revert DSCEngine__TokenNotAllowed(collateralAddress);
        }
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__InvalidAmount();
        }
        _;
    }

    /* Functions */
    constructor(
        address[] memory acceptedCollateralTokenAddress, 
        address[] memory collateralTokenPriceFeedAddress, 
        address dscTokenAddress
        ) 
    {
        if (dscTokenAddress == address(0)) {
            revert DSCEngine__TokenAddressCannotBeZero();
        }
        if (acceptedCollateralTokenAddress.length != collateralTokenPriceFeedAddress.length) {
            revert DSCEngine__ConstructorInputParamsMismatch(
                acceptedCollateralTokenAddress.length,
                collateralTokenPriceFeedAddress.length);
        }
        for(uint256 i=0;i<acceptedCollateralTokenAddress.length;i++) {
            if (acceptedCollateralTokenAddress[i] == address(0)) {
                revert DSCEngine__CollateralTokenAddressCannotBeZero();
            }
            if (collateralTokenPriceFeedAddress[i] == address(0)) {
                revert DSCEngine__PriceFeedAddressCannotBeZero();
            }
            s_tokenToPriceFeed[acceptedCollateralTokenAddress[i]] = collateralTokenPriceFeedAddress[i];
        }
        i_dscToken = dscTokenAddress;
    }

    function depositCollateralMintDSC() external {}

    function depositCollateral(
        address collateralTokenAddress,
        uint256 collateralAmount
        ) external 
        onlyAllowedTokens(collateralTokenAddress) 
        moreThanZero(collateralAmount) 
        nonReentrant 
        {
            // 1st update state and send emits
            s_userToCollateralDeposited[msg.sender][collateralTokenAddress] += collateralAmount;
            emit CollateralDeposited(msg.sender,collateralTokenAddress,collateralAmount);

            // then perform actual action to effect the state change
            bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender,address(this),collateralAmount);
            if (!success) {
                // Question: Will this revert also rollback the earlier statements in this function call?
                // ie: Will the state change and the emit be rolled back too?
                revert DSCEngine__TransferFailed(msg.sender,address(this),collateralTokenAddress,collateralAmount);
            }
        }

    function redeemCollateralBurnDSC() external {}

    function redeemCollateral() external {}

    function mintDSC() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthStatus() external {}

}