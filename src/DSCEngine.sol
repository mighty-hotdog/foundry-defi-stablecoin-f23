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
    // record of all allowed collateral tokens, each mapped to their respective price feed
    mapping(address allowedTokenAddress => address tokenPriceFeed) private s_tokenToPriceFeed;
    // record of all collateral deposits, maps the user/depositor, to the collateral token address, to the amount deposited
    mapping(address user => mapping(address collateralTokenAddress => uint256 collateralAmountDeposited)) private s_userToCollateralDeposited;
    // Question: Is it better here to use a mapping or an array of structs?
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
        address[] memory allowedCollateralTokenAddresses, 
        address[] memory collateralTokenPriceFeedAddresses, 
        address dscToken
        ) 
    {
        if (dscToken == address(0)) {
            revert DSCEngine__TokenAddressCannotBeZero();
        }
        if (allowedCollateralTokenAddresses.length != collateralTokenPriceFeedAddresses.length) {
            revert DSCEngine__ConstructorInputParamsMismatch(
                allowedCollateralTokenAddresses.length,
                collateralTokenPriceFeedAddresses.length);
        }
        for(uint256 i=0;i<allowedCollateralTokenAddresses.length;i++) {
            if (allowedCollateralTokenAddresses[i] == address(0)) {
                revert DSCEngine__CollateralTokenAddressCannotBeZero();
            }
            if (collateralTokenPriceFeedAddresses[i] == address(0)) {
                revert DSCEngine__PriceFeedAddressCannotBeZero();
            }
            s_tokenToPriceFeed[allowedCollateralTokenAddresses[i]] = collateralTokenPriceFeedAddresses[i];
        }
        i_dscToken = dscToken;
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
                //  ie: Will the state change and the emit be rolled back too?
                // Answer: Yes. On revert, the execution of a function is terminated. All changes to the state 
                //  variables since the beginning of the current function call are undone, returning the state 
                //  to what it was before the function was called. This ensures transactions remain atomic and
                //  consistent, preventing partial updates that could lead to inconsistent states.
                //  A revert will also roll back any events emitted earlier in the same function call.
                // Also: Upon encountering a revert, the EVM (Ethereum Virtual Machine) refunds the unused gas 
                //  to the caller. This is to ensure that callers are not charged for operations that were not 
                //  completed successfully.
                // Additionally: When a contract function calls another contract and that call reverts, the 
                //  calling function can choose to handle the revert gracefully using a try/catch block. This 
                //  allows the caller to detect the revert and take appropriate action, such as logging the 
                //  error or attempting alternative actions. The try/catch construct does not automatically 
                //  revert state changes. It merely allows the caller to react to the revert condition.
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