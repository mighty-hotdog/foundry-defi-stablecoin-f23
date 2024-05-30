// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 *  @title  DSCEngine
 *  @notice This contract defines and implements the logic to manage the Decentralized Stablecoin token.
 *  @dev    This contract is the Owner of the DecentralizedStableCoin contract.
 *          Stablecoin characteristics to be implemented and enforced by this contract:
 *              Collateral: Exogenous (specifically wETH & wBTC)
 *              Relative Stability: Anchored (ie: pegged to USD 1:1)
 *              Stability Mechanism: Decentralized Algorithmic
 *          Makes use of Chainlink Price Feeds.
 */
contract DSCEngine is ReentrancyGuard {
    /* Errors */
    error DSCEngine__TokenNotAllowed(address tokenAddress);
    error DSCEngine__ThresholdOutOfRange(uint256 threshold);
    error DSCEngine__InvalidAmount();
    error DSCEngine__ConstructorInputParamsMismatch(uint256 lengthOfCollateralAddressesArray,uint256 lengthOfPriceFeedsArray);
    error DSCEngine__CollateralTokenAddressCannotBeZero();
    error DSCEngine__PriceFeedAddressCannotBeZero();
    error DSCEngine__TokenAddressCannotBeZero();
    error DSCEngine__TransferFailed(address from,address to,address collateralTokenAddress,uint256 amount);
    error DSCEngine__RequestedMintAmountBreachesMintLimit(address user,uint256 requestedMintAmount,uint256 maxSafeMintAmount);
    error DSCEngine__DataFeedError(address tokenAddress, address priceFeedAddress, int answer);
    error DSCEngine__MintFailed(address toUser,uint256 amountMinted);

    /* State Variables */
    uint256 public constant FRACTIONS_REMOVAL_ADJUSTER = 100;
    address private immutable i_dscToken;
    uint256 private immutable i_thresholdLimitPercent;  // NOTE: value only ranges between 1 and 99 inclusive
    // array of all allowed collateral tokens
    address[] private s_allowedCollateralTokens;
    // maps each allowed collateral token to its respective price feed
    mapping(address allowedTokenAddress => address tokenPriceFeed) private s_tokenToPriceFeed;
    // maps each existing user to collateral token, to the amount of deposit he currently holds in that token
    // Question: Is it better here to use a mapping or an array of structs?
    mapping(address user => mapping(address collateralTokenAddress => uint256 amountOfCurrentDeposit)) private s_userToCollateralDepositHeld;
    // maps each existing user to the amount of DSC he currently holds
    // Question: Is it better here to use a mapping or an array of structs?
    mapping(address user => uint256 dscAmountHeld) s_userToDSCMintHeld;

    /* Events */
    event CollateralDeposited(address indexed user,address indexed collateralTokenAddress,uint256 indexed amount);
    event DSCMinted(address indexed toUser,uint256 indexed amount);

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

    modifier withinMintLimitSimple(address user, uint256 amountToMint) {
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Approach 1 - simplified
        //              apply a single threshold limit to compare total deposit value vs total mint value
        //              factor = (total deposit value * threshold %) / total mint value
        //              user is within mint limits if factor > 1
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // calc/obtain total value of user's deposits //////////////////
        uint256 valueOfDepositsHeld = getValueOfDepositsHeldInUsd(user);
        // calc/obtain total value of user's mints so far //////////////
        uint256 valueOfMintsHeld = getValueOfMintsHeldInUsd(user);
        // subject the 2 values to algo check //////////////////////////
        /* Algorithm Description
         * i_thresholdLimitPercent is the threshold limit in percentage.
         *  eg: if limit is 80%, then i_thresholdLimitPercent = 80
         * FRACTIONS_REMOVAL_ADJUSTER is the multiplication factor needed to remove fractions.
         *  eg: if i_thresholdLimitPercent = 80, then FRACTIONS_REMOVAL_ADJUSTER = 100
         *  because threshold value of deposits held = (valueOfDepositsHeld * i_thresholdLimitPercent) / 100
         *  but to remove fractions and deal solely in integers, need to multiply by 100.
         *  similiarly, the denominator valueOfMintsHeld also needs to be multiplied by 100.
         */
        //uint256 factor = (valueOfDepositsHeld * i_thresholdLimitPercent) / ((valueOfMintsHeld + amountToMint) * FRACTIONS_REMOVAL_ADJUSTER);
        uint256 numerator = valueOfDepositsHeld * i_thresholdLimitPercent;
        uint256 denominator = (valueOfMintsHeld + amountToMint) * FRACTIONS_REMOVAL_ADJUSTER;
        // revert if mint limit breached
        if (denominator > numerator) {
            uint256 maxSafeMintAmount = (numerator - (valueOfMintsHeld * FRACTIONS_REMOVAL_ADJUSTER)) / FRACTIONS_REMOVAL_ADJUSTER;
            // integer math may result in maxSafeMintAmount == 0, which is still logically correct
            revert DSCEngine__RequestedMintAmountBreachesMintLimit(user,amountToMint,maxSafeMintAmount);
        }
        _;
    }

    modifier withinMintLimitReal(address user, uint256 amountToMint) {
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Approach 2 - realistic and more flexible
        //              each allowed collateral is assigned its own threshold limit
        //              factor = sumOf(collateral Z total deposit value * collateral Z threshold %) / total mint value
        //              user is within mint limits if factor > 1
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        _;
    }

    /* Functions */
    constructor(
        address[] memory allowedCollateralTokenAddresses, 
        address[] memory collateralTokenPriceFeedAddresses, 
        address dscToken,
        uint256 thresholdPercent
        ) 
    {
        if (dscToken == address(0)) {
            revert DSCEngine__TokenAddressCannotBeZero();
        }
        if ((thresholdPercent < 1) || (thresholdPercent > 99)) {
            revert DSCEngine__ThresholdOutOfRange(thresholdPercent);
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
            s_allowedCollateralTokens.push(allowedCollateralTokenAddresses[i]);
        }
        i_dscToken = dscToken;
        i_thresholdLimitPercent = thresholdPercent;
    }

    function depositCollateralMintDSC() external {}

    /**
     *  @notice depositCollateral()
     *  @param  collateralTokenAddress  collateral token contract address
     *  @param  collateralAmount    amount of collateral to deposit
     *  @dev    2 checks performed:
     *              1. deposit is in allowed tokens
     *              2. deposit amount is more than zero
     *          if both checks passed, then proceed to:
     *              1. record deposit (ie: change internal state)
     *              2. emit event
     *              3. perform the actual token transfer
     */
    function depositCollateral(
        address collateralTokenAddress,
        uint256 collateralAmount
        ) external 
        onlyAllowedTokens(collateralTokenAddress) 
        moreThanZero(collateralAmount) 
        nonReentrant 
        {
            // 1st update state and send emits
            s_userToCollateralDepositHeld[msg.sender][collateralTokenAddress] += collateralAmount;
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

    /**
     *  @dev    checks performed:
     *              1. mint amount is more than zero
     *              2. msg.sender's mint limit has not been breached
     *          if both checks passed, then proceed:
     *              1. record mint (ie: change internal state)
     *              2. emit event
     *              3. perform actual mint/token transfer
     */
    function mintDSC(uint256 amount) external moreThanZero(amount) withinMintLimitSimple(msg.sender,amount) {
        // 1st update state and send emits
        s_userToDSCMintHeld[msg.sender] += amount;
        emit DSCMinted(msg.sender,amount);

        // then perform actual action to effect the state change
        bool success = DecentralizedStableCoin(i_dscToken).mint(msg.sender, amount);
        if (!success) {
            revert DSCEngine__MintFailed(msg.sender,amount);
        }
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthStatus() external {}

    function convertToValueInUsd(
        address token, 
        uint256 amount) 
        internal view onlyAllowedTokens(token) 
        returns (uint256 valueInUsd)
    {
        if (amount == 0) {
            return 0;
        }
        // obtain price feed address
        address priceFeed = s_tokenToPriceFeed[token];
        // obtain token price from price feed
        (,int answer,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) {
            revert DSCEngine__DataFeedError(token,priceFeed,answer);
        }
        // multiply amount by token price and return value in USD
        return uint256(answer) * amount;
    }

    function getValueOfDepositsHeldInUsd(address user) internal view returns (uint256 valueInUsd) {
        // loop through all allowed collateral tokens
        for(uint256 i=0;i<s_allowedCollateralTokens.length;i++) {
            // obtain deposit amount held by user in each collateral token
            uint256 depositHeld = s_userToCollateralDepositHeld[user][s_allowedCollateralTokens[i]];
            if (depositHeld > 0) {
                // convert to USD value and add to return value
                valueInUsd += convertToValueInUsd(s_allowedCollateralTokens[i],depositHeld);
            }
        }
        //return valueInUsd;    // redundant
    }

    function getValueOfMintsHeldInUsd(address user) internal view returns (uint256 valueInUsd) {
        // since DSC token is USD pegged 1:1, no extra logic needed to convert DSC token to USD value
        return s_userToDSCMintHeld[user];
    }
}