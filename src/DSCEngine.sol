// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
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
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Errors *//////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    error DSCEngine__TokenNotAllowed(address tokenAddress);
    error DSCEngine__ThresholdOutOfRange(uint256 threshold);
    error DSCEngine__AmountCannotBeZero();
    error DSCEngine__ConstructorInputParamsMismatch(
        uint256 lengthOfCollateralAddressesArray,
        uint256 lengthOfPriceFeedsArray,
        uint256 lengthOfPriceFeedsPrecisionArray);
    error DSCEngine__TokenAddressCannotBeZero();
    error DSCEngine__PriceFeedAddressCannotBeZero();
    error DSCEngine__PriceFeedPrecisionCannotBeZero();
    error DSCEngine__DscTokenAddressCannotBeZero();
    // this error will never hit because ERC20's transfer() and transferFrom() just return true no matter what
    //error DSCEngine__TransferFailed(address from,address to,address collateralTokenAddress,uint256 amount);
    error DSCEngine__RequestedMintAmountBreachesUserMintLimit(
        address user,uint256 requestedMintAmount,uint256 maxSafeMintAmount);
    error DSCEngine__DataFeedError(address tokenAddress, address priceFeedAddress, int answer);
    error DSCEngine__MintFailed(address toUser,uint256 amountMinted);
    error DSCEngine__OutOfArrayRange(uint256 maxIndex,uint256 requestedIndex);
    error DSCEngine__RequestedBurnAmountExceedsBalance(
        address user,uint256 dscAmountHeldByUser,uint256 requestedBurnAmount);
    error DSCEngine__RequestedRedeemAmountExceedsBalance(
        address user,address requestedRedeemCollateral,uint256 collateralHeldAmount,uint256 requestedRedeemAmount);
    error DSCEngine__RequestedRedeemAmountBreachesUserRedeemLimit(
        address user,address requestedRedeemCollateral,uint256 requestedRedeemAmount,uint256 maxSafeRedeemAmount);
    error DSCEngine__UserCannotBeZero();
    error DSCEngine__MintsCannotBeZero();
    error DSCEngine__DepositsCannotBeZero();
    error DSCEngine__CannotBeLiquidated(address user);
    error DSCEngine__UserDebtExceedsLiquidatorBalance(uint256 valueOfDscMints,uint256 liquidatorDscBalance);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Custom Types *////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    struct PriceFeed {
        address priceFeed;
        uint256 precision;
    }

    // a Holding defines a single record of a token deposit or mint
    struct Holding {
        address token;
        bool isCollateral;
        uint256 amount;
        uint256 currentPrice;
        uint256 currentValueInUsd;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* State Variables - Generics *//////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    uint256 private constant FRACTION_REMOVAL_MULTIPLIER = 100;
    address private immutable i_dscToken;   // contract address for the DSC token
    uint256 private immutable i_thresholdLimitPercent;  // the single threshold limit to be applied to total value 
                                                        //  of collateral deposits in the modifier withinMintLimitSimple()
                                                        // NOTE: value is code-enforced to range between 1 and 99 inclusive
    // array of all allowed collateral tokens
    address[] private s_allowedCollateralTokens;
    // maps each allowed collateral token to its respective price feed and the associated precision of the price feed
    mapping(address allowedTokenAddress => PriceFeed tokenPriceFeed) private s_tokenToPriceFeed;

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* State Variables - User Records & Information *////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // maps each existing user to each collateral token, to the amount of deposit he currently holds in the system 
    //  for that token.
    // Question: Is it better here to use a mapping or an array of structs?
    mapping(address user => mapping(address collateralTokenAddress => uint256 amountOfCurrentDeposit)) 
        private s_userToCollateralDeposits;
    // maps each existing user to the amount of DSC tokens he has minted (ie: borrowed), that has not yet been burned 
    //  (ie: returned).
    // Question: Is it better here to use a mapping or an array of structs?
    mapping(address user => uint256 dscAmountHeld) private s_userToDscMints;

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Events *//////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    event CollateralDeposited(address indexed user,address indexed collateralTokenAddress,uint256 indexed amount);
    event CollateralRedeemed(address indexed user,address indexed collateralTokenAddress,uint256 indexed amount);
    event DSCMinted(address indexed toUser,uint256 indexed amount);
    event DSCBurned(address indexed fromUser,uint256 indexed amount);
    event Liquidated(address indexed user,uint256 indexed valueOfDscMints,uint256 indexed valueOfDeposits);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Modifiers *///////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    modifier onlyAllowedTokens(address collateralAddress) {
        if (collateralAddress == address(0)) {
            revert DSCEngine__TokenAddressCannotBeZero();
        }
        if (s_tokenToPriceFeed[collateralAddress].priceFeed == address(0)) {
            revert DSCEngine__TokenNotAllowed(collateralAddress);
        }
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__AmountCannotBeZero();
        }
        _;
    }

    modifier nonZeroUser(address user) {
        if (user == address(0)) {
            revert DSCEngine__UserCannotBeZero();
        }
        _;
    }

    // modifier restricts function caller to:
    //  1. app contracts serving account user
    //  2. account user
    // Intended use is to protect user privacy in functions that retrieve user account information.
    // Question: Is such a restriction meaningful? On blockchain user balances are already visible to everyone.
    // Answer: Yes it is meaningful. Actually a full access control mechanism would be appropriate for a wallet 
    //  app and other defi apps in general.
    // ***TODO***: Study TornadoCash design, specifically the part that protects users' privacy by using shared
    //  crypto pools to break up direct traceability to original senders/receivers.
    modifier onlyAuthorizedUsers() {
        _;
    }

    modifier withinMintLimitSimple(address user, uint256 requestedMintAmount) {
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Approach 1 - simplified
        //              apply a single threshold limit to total deposit value regardless of collateral
        //              factor = (total deposit value * threshold %) / total mint value
        //              user is within mint limits if factor > 1
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // calc/obtain total value of user's deposits //////////////////
        uint256 valueOfDeposits = getValueOfDepositsInUsd(user);
        // calc/obtain total value of user's mints so far //////////////
        uint256 valueOfDscMints = getValueOfDscMintsInUsd(user);
        // subject the 2 values to algo check //////////////////////////
        /* Algorithm:
         *  uint256 factor = (valueOfDeposits * i_thresholdLimitPercent) / 
         *                      ((valueOfDscMints + requestedMintAmount) * FRACTION_REMOVAL_MULTIPLIER);
         *      factor > 1  ie: account is healthy
         *      factor < 1  ie: account is in arrears
         * Algorithm Description & Explanation
         * i_thresholdLimitPercent is the single threshold limit in percentage.
         *  eg: if threshold limit is 80%, then i_thresholdLimitPercent = 80
         * FRACTION_REMOVAL_MULTIPLIER is the multiplication factor needed to remove fractions.
         *  eg: if i_thresholdLimitPercent = 80, then FRACTION_REMOVAL_MULTIPLIER = 100
         *  This is needed because threshold value of deposits held = (valueOfDeposits * i_thresholdLimitPercent) / 100.
         *  But to remove fractions and deal solely in integers, need to multiply by 100.
         *  Similiarly, the denominator (valueOfDscMints + requestedMintAmount) also needs to be multiplied by 100.
         */
        uint256 numerator = valueOfDeposits * i_thresholdLimitPercent;
        uint256 denominator = (valueOfDscMints + requestedMintAmount) * FRACTION_REMOVAL_MULTIPLIER;

        // revert if mint limit breached
        if (denominator > numerator) {
            // Integer math may result in maxSafeMintAmount == 0, which is still logically correct.
            // Question: Is there a way for maxSafeMintAmount to be used outside this modifier in the main 
            //  function to indicate account's "health".
            // Answer: No there isn't. By design, modifier variables are scope limited to be outside scope
            //  of the main function.
            uint256 maxSafeMintAmount = 
                (numerator - (valueOfDscMints * FRACTION_REMOVAL_MULTIPLIER)) / FRACTION_REMOVAL_MULTIPLIER;
            revert DSCEngine__RequestedMintAmountBreachesUserMintLimit(user,requestedMintAmount,maxSafeMintAmount);
        }
        _;
    }

    modifier withinMintLimitReal(address user, uint256 requestedMintAmount) {
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Approach 2 - realistic and more flexible
        //              each allowed collateral is assigned its own threshold limit, in consideration of the volatility 
        //                  of its price and/or other market conditions.
        //              factor = sumOf(collateral Z total deposit value * collateral Z threshold %) / total mint value
        //              user is within mint limits if factor > 1
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        _;
    }

    modifier sufficientBalance(address user,address token,uint256 amount) {
        if (token == i_dscToken) {
            // if token is DSC, check that user holds sufficient token balance
            uint256 dscBalance = DecentralizedStableCoin(token).balanceOf(user);
            if (amount > dscBalance) {
                revert DSCEngine__RequestedBurnAmountExceedsBalance(user,dscBalance,amount);
            }
        } else {
            // if token is collateral, check that user has sufficient deposits of this collateral in system
            uint256 deposit = s_userToCollateralDeposits[user][token];
            if (deposit < amount) {
                revert DSCEngine__RequestedRedeemAmountExceedsBalance(user,token,deposit,amount);
            }
        }
        _;
    }

    modifier withinRedeemLimitSimple(address user,address collateral,uint256 requestedRedeemAmount) {
        uint256 valueOfDscMints = getValueOfDscMintsInUsd(user);
        // if valueOfDscMints == 0, ie: no DSC minted, no user debt to system, hence free to redeem 
        //  any amount even all deposits, therefore just skip all the calcs and continue w/ main 
        //  function.
        if (valueOfDscMints > 0) {
            uint256 valueOfDeposits = getValueOfDepositsInUsd(user);
            uint256 valueOfRequestedRedeemAmount = convertToUsd(collateral,requestedRedeemAmount);
            uint256 numerator = (valueOfDeposits - valueOfRequestedRedeemAmount) * i_thresholdLimitPercent;
            uint256 denominator = valueOfDscMints * FRACTION_REMOVAL_MULTIPLIER;

            if (denominator > numerator) {
                uint256 maxSafeRedeemAmount = 
                    ((valueOfDeposits * i_thresholdLimitPercent) - denominator) / i_thresholdLimitPercent;
                maxSafeRedeemAmount = convertFromUsd(maxSafeRedeemAmount,collateral);
                revert DSCEngine__RequestedRedeemAmountBreachesUserRedeemLimit(
                    user,collateral,requestedRedeemAmount,maxSafeRedeemAmount);
            }
        }
        _;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Constructor */////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    constructor(
        address[] memory allowedCollateralTokenAddresses, 
        address[] memory collateralTokenPriceFeedAddresses, 
        uint256[] memory priceFeedPrecision,
        address dscToken,
        uint256 thresholdPercent
        ) 
    {
        if (dscToken == address(0)) {
            revert DSCEngine__DscTokenAddressCannotBeZero();
        }
        if ((thresholdPercent < 1) || (thresholdPercent > 99)) {
            revert DSCEngine__ThresholdOutOfRange(thresholdPercent);
        }
        if (!((allowedCollateralTokenAddresses.length == collateralTokenPriceFeedAddresses.length) &&
            (allowedCollateralTokenAddresses.length == priceFeedPrecision.length))) {
            revert DSCEngine__ConstructorInputParamsMismatch(
                allowedCollateralTokenAddresses.length,
                collateralTokenPriceFeedAddresses.length,
                priceFeedPrecision.length);
        }
        for(uint256 i=0;i<allowedCollateralTokenAddresses.length;i++) {
            if (allowedCollateralTokenAddresses[i] == address(0)) {
                revert DSCEngine__TokenAddressCannotBeZero();
            }
            if (collateralTokenPriceFeedAddresses[i] == address(0)) {
                revert DSCEngine__PriceFeedAddressCannotBeZero();
            }
            if (priceFeedPrecision[i] == 0) {
                revert DSCEngine__PriceFeedPrecisionCannotBeZero();
            }
            s_tokenToPriceFeed[allowedCollateralTokenAddresses[i]] = PriceFeed({
                priceFeed: collateralTokenPriceFeedAddresses[i],
                precision: priceFeedPrecision[i]});
            s_allowedCollateralTokens.push(allowedCollateralTokenAddresses[i]);
        }
        i_dscToken = dscToken;
        i_thresholdLimitPercent = thresholdPercent;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* User-facing Functions *///////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     *  These functions serve users of the platform by providing some functionality or utility.
     *  Each function is meant to be called directly by the user.
     *  As such, they all make use of msg.sender to activate whatever feature/functionality they implement/provide.
     */
    function getAccountFullInfo() external {
        // returns:
        //  1. user account status:
        //      a. green = healthy
        //      b. yellow = concern (specific items of concern highlighted)
        //      c. orange = warning (specific items of concern highlighted)
        //      d. red = suspended (in arrears amount + specific violations highlighted)
        //  2. all tokens held by user, listed by:
        //      a. token
        //      b. is token a collateral
        //      c. amount
        //      d. current price
        //      e. current value in usd
        //  3. total tokens value in usd held by user
        //  4. total deposits value in usd held by user
        //  5. total mints value in usd held by user
        //  6. all still-in-effect approvals/delegates granted by user, listed by:
        //      a. status (in-effect,depleted,cancelled)
        //      b. spender
        //      c. original amount approved
        //      d. datetime of approval
        //      e. remaining amount
    }
    function getAccountStatus() external {
        // returns user account status:
        //      a. green = healthy
        //      b. yellow = concern (specific items of concern highlighted)
        //      c. orange = warning (specific items of concern highlighted)
        //      d. red = suspended (in arrears amount + specific violations highlighted)
    }
    function getAllDeposits() public view returns (Holding[] memory) {
        // returns all deposits held by user, listed by:
        //      a. token
        //      b. amount
        //      c. current price
        //      d. current value in usd
        Holding[] memory deposits = new Holding[](s_allowedCollateralTokens.length);
        for(uint256 i=0;i<s_allowedCollateralTokens.length;i++) {
            address collateral = s_allowedCollateralTokens[i];
            uint256 depositAmount = s_userToCollateralDeposits[msg.sender][collateral];
            uint256 price = convertToUsd(collateral,1);
            uint256 value = convertToUsd(collateral,depositAmount);
            deposits[i] = (Holding({
                token: collateral,
                isCollateral: true,
                amount: depositAmount,
                currentPrice: price,
                currentValueInUsd: value
            }));
        }
        return deposits;
    }
    function getDepositAmount(address token) external view onlyAllowedTokens(token) returns (uint256) {
        return s_userToCollateralDeposits[msg.sender][token];
    }
    function getDepositsValueInUsd() external view returns (uint256) {
        // returns total deposits value in usd held by user
        return getValueOfDepositsInUsd(msg.sender);
    }
    function getMints() external view returns (uint256) {
        // returns total mint amount held by user
        return s_userToDscMints[msg.sender];
    }
    function getMintsValueInUsd() external view returns (uint256) {
        // returns total mint value in usd held by user
        return getValueOfDscMintsInUsd(msg.sender);
    }
    function getTokensHeld() external view returns (Holding[] memory) {
        // returns all tokens held by user, listed by:
        //      a. token
        //      b. is this a collateral
        //      c. amount
        //      d. current price
        //      e. current value in usd
        Holding[] memory deposits = getAllDeposits();
        Holding[] memory holdings = new Holding[](deposits.length + 1); // + 1 to include the mint token dsc
        holdings[0] = Holding({
            token: i_dscToken,
            isCollateral: false,
            amount: s_userToDscMints[msg.sender],
            currentPrice: 1,
            currentValueInUsd: getValueOfDscMintsInUsd(msg.sender)
        });
        for(uint256 i=1;i<holdings.length;++i) {
            holdings[i] = deposits[i-1];
        }
        return holdings;
    }
    function getTokensHeldValueInUsd() external view returns (uint256) {
        // returns total tokens value in usd held by user
        return getValueOfDepositsInUsd(msg.sender) + getValueOfDscMintsInUsd(msg.sender);
    }

    // these approval user functions are questionable in usefulness, since the only appropriate
    //  spender in here is the DSCEngine. In any case, ERC20 and its associated interfaces do
    //  not seem to allow approval/spender/allowance records to be retrieved.
    /*
    function getApprovals() external {
        // returns all still-in-effect approvals/delegates granted by user, listed by:
        //      a. status (in-effect,depleted,cancelled)
        //      b. spender
        //      c. original amount approved
        //      d. datetime of approval
        //      e. remaining amount
    }
    function cancelApproval() external {}
    function grantApproval() external {}
    */

    /**
     *  @notice depositCollateralMintDSC()
     *          for any user to call.
     *          convenience function combining depositCollateral() and mintDSC() in single call to save gas.
     *  @param  collateral  collateral token contract address
     *  @param  depositAmount  amount of collateral to deposit
     *  @param  mintAmount amount of DSC token to be requested for mint
     *  @dev    all needed checks alrdy implemented in the constituent functions.
     *  @dev    user is msg.sender.
     */
    function depositCollateralMintDSC(
        address collateral,
        uint256 depositAmount,
        uint256 mintAmount
        ) external 
    {
        depositCollateral(collateral, depositAmount);
        mintDSC(mintAmount);
    }

    /**
     *  @notice depositCollateral()
     *          for any user to call, to deposit collaterals into his own account
     *          also called in convenience function depositCollateralMintDSC() in combination with mintDSC().
     *  @param  collateralTokenAddress  collateral token contract address
     *  @param  requestedDepositAmount  amount of collateral to deposit
     *  @dev    checks performed:
     *              1. deposit is in allowed tokens
     *              2. deposit amount is more than zero
     *          if all checks passed, then proceed to:
     *              1. record deposit (ie: change internal state)
     *              2. emit event
     *              3. perform the actual token transfer
     *  @dev    user is msg.sender.
     *  @dev    public, to allow depositCollateralMintDSC() to call.
     */
    function depositCollateral(
        address collateralTokenAddress,
        uint256 requestedDepositAmount
        ) public 
        moreThanZero(requestedDepositAmount) 
        onlyAllowedTokens(collateralTokenAddress) 
        nonReentrant 
    {
        // 1st update state and send emits,
        s_userToCollateralDeposits[msg.sender][collateralTokenAddress] += requestedDepositAmount;
        emit CollateralDeposited(msg.sender,collateralTokenAddress,requestedDepositAmount);

        // then perform actual action to effect the state change.
        
        // Basically the external user who called depositCollateral() is msg.sender.
        // From within depositCollateral(), the DSCEngine calls transferFrom() to make the actual transfer
        //  of tokens. This means DSCEngine is the "spender" that the user needs to approve 1st with an
        //  appropriate allowance of the token to be transferred.
        // In this case, the "to address" to transfer the tokens to is the DSCEngine itself.
        IERC20(collateralTokenAddress).transferFrom(msg.sender,address(this),requestedDepositAmount);
        /*
        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender,address(this),requestedDepositAmount);
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
            revert DSCEngine__TransferFailed(msg.sender,address(this),collateralTokenAddress,requestedDepositAmount);
        }
        */
    }

    /**
     *  @notice mintDSC()
     *          for a user to call, to mint DSC on his own account.
     *          also called in convenience function depositCollateralMintDSC() in combination with depositCollateral().
     *  @param  requestedMintAmount amount of DSC token to be requested for mint
     *  @dev    checks performed:
     *              1. mint amount is more than zero
     *              2. user's mint limit is not been breached with this mint request
     *          if all checks passed, then proceed:
     *              1. record mint (ie: change internal state)
     *              2. emit event
     *              3. perform actual mint and token transfer
     *  @dev    user is msg.sender.
     *  @dev    public, to allow depositCollateralMintDSC() to call.
     */
    function mintDSC(
        uint256 requestedMintAmount
        ) public 
        moreThanZero(requestedMintAmount) 
        withinMintLimitSimple(msg.sender,requestedMintAmount) 
        nonReentrant
    {
        // 1st update state and send emits
        s_userToDscMints[msg.sender] += requestedMintAmount;
        emit DSCMinted(msg.sender,requestedMintAmount);

        // then perform actual action to effect the state change
        bool success = DecentralizedStableCoin(i_dscToken).mint(msg.sender, requestedMintAmount);
        if (!success) {
            revert DSCEngine__MintFailed(msg.sender,requestedMintAmount);
        }
    }

    /**
     *  @notice redeemCollateralBurnDSC()
     *          for any user to call.
     *          convenience function combining _burnDSC() and _redeemCollateral() in single call to save gas.
     *  @param  requestedBurnAmount DSC amount to burn
     *  @param  collateralTokenAddress  collateral to redeem
     *  @param  requestedRedeemAmount amount to redeem
     *  @dev    all needed checks alrdy implemented in the constituent functions.
     *  @dev    user is msg.sender.
     */
    function redeemCollateralBurnDSC(
        uint256 requestedBurnAmount,
        address collateralTokenAddress,
        uint256 requestedRedeemAmount
        ) external 
    {
        _burnDSC(msg.sender,msg.sender,requestedBurnAmount);
        _redeemCollateral(msg.sender,msg.sender,collateralTokenAddress,requestedRedeemAmount);
    }

    /**
     *  @notice redeemCollateral()
     *          for any user to call, to redeem collaterals held in his own account
     *  @param  collateralTokenAddress  collateral token contract address
     *  @param  requestedRedeemAmount  amount of collateral to requested for redemption
     *  @dev    all checks are performed in the constituent function _redeemCollateral():
     *              1. redeem amount is more than zero
     *              2. redemption is in allowed tokens
     *              3. sufficient balance exists in collateral held
     *              4. user's redeem limit is not breached with this redemption request
     *          all implementation logic in constituent function _redeemCollateral():
     *              1. record redemption (ie: change internal state)
     *              2. emit event
     *              3. perform the actual token transfer
     *  @dev    user is msg.sender.
     */
    function redeemCollateral(address collateralTokenAddress,uint256 requestedRedeemAmount) external {
        _redeemCollateral(msg.sender,msg.sender,collateralTokenAddress,requestedRedeemAmount);
    }

    /**
     *  @notice burnDSC()
     *          for any user to call, to burn minted dsc tokens held in his own account
     *  @param  requestedBurnAmount  amount of dsc tokens to burn
     *  @dev    all checks are performed in the constituent function _burnDSC():
     *              1. burn amount is more than zero
     *              2. sufficient balance exists in user account
     *          all implementation logic in constituent function _burnDSC():
     *              1. record burn (ie: pay down user debt)
     *              2. emit event
     *              3. perform the token transfer from user balance to DSCEngine
     *              4. DSCEngine performs the actual burn
     *  @dev    user is msg.sender.
     */
    function burnDSC(uint256 requestedBurnAmount) external {
        _burnDSC(msg.sender,msg.sender,requestedBurnAmount);
    }

    function liquidate(address userToLiquidate) external nonReentrant nonZeroUser(userToLiquidate) {
        // Question: What is liquidation?
        // Answer: Paying off a user's debt (minted dsc tokens in this case) and receiving the value of 
        //  his deposits backing that debt.
        // Question: Who can liquidate?
        // Answer: Other users in the system.
        // Question: Under what circumstances will they "pull the trigger" to liquidate?
        // Answer: When they profit from it. Taking a simplistic approach:
        //  liquidators watch for the "right" moment to pull the trigger, which is when the value of a 
        //  user's collaterals fall below the required system threshold limit, but is still well above 
        //  the value of his debt which they are backing.
        //  Upon triggering the liquidation, the liquidator pays a lower value (the debt) in return for 
        //  a higher value (the collaterals, which the liquidator receive directly and in full from the 
        //  liquidation event).
        // Question: So how does this whole liquidation play out?
        // Answer: 
        //  A deposits $8000 ETH (at $4000/ETH) and mints $4000 DSC.
        //      A collateral deposits: $8000 (2 ETH tokens)
        //      A debt: $4000 (ie: minted 4000 DSC)
        //      A DSC tokens held: 4000
        //      A ETH tokens held: 0
        //      A total balance: $8000
        //  Price of ETH plunges to $3000. A's collateral is now worth $6000.
        //      A collateral: $6000 (still 2 ETH tokens)
        //      A debt: $4000
        //      A DSC tokens held: 4000
        //      A ETH tokens held: 0
        //      A total balance: $6000
        //  System collateralization requirement is 200%. This means A is now undercollateralized and can be liquidated.
        //  B steps in to liquidate A.
        //  B deposits $8000 ETH (at $3000/ETH) and mints $4000 DSC.
        //      B collateral deposits: $8000 (2.67 ETH tokens)
        //      B debt: $4000 (ie: minted 4000 DSC)
        //      B DSC tokens held: 4000
        //      B ETH tokens held: 0
        //      B total balance: $8000
        //  B liquidates A by paying A's debt with B's own DSC tokens, then redeems A's collaterals.
        //      A collateral: $0            B collateral: $8000 (still 2.67 ETH tokens)
        //      A debt: $0                  B debt: $4000
        //      A DSC tokens held: 4000     B DSC tokens held: 0
        //      A ETH tokens held: 0        B ETH tokens held: 2 (at $3000/ETH)
        //      A total balance: $4000      B total balance: $10,000
        //  
        //  checks performed:
        //      1. user to liquidate has non-zero deposits and mints
        //      2. user to liquidate is below required threshold limit for deposits vs mints balance
        //      3. liquidator has sufficient balance (ie: dsc tokens) to pay for full liquidation amount
        //  if all checks passed, carry out the liquidation:
        //      1. liquidator
        //          a. burns DSC tokens
        //          b. redeems collateral tokens
        //      2. liquidated user
        //          a. debt (ie: DSC mints) is zeroed
        //          b. collateral deposits is also zeroed
        
        // all checks //////////////////////////////////////////////////////////////
        uint256 valueOfDscMints = getValueOfDscMintsInUsd(userToLiquidate);
        if (valueOfDscMints == 0) {
            revert DSCEngine__MintsCannotBeZero();
        }
        uint256 valueOfDeposits = getValueOfDepositsInUsd(userToLiquidate);
        if (valueOfDeposits == 0) {
            revert DSCEngine__DepositsCannotBeZero();
        }
        uint256 liquidatorDscBalance = DecentralizedStableCoin(i_dscToken).balanceOf(msg.sender);
        if (liquidatorDscBalance < valueOfDscMints) {
            revert DSCEngine__UserDebtExceedsLiquidatorBalance(valueOfDscMints,liquidatorDscBalance);
        }
        uint256 numerator = valueOfDeposits * i_thresholdLimitPercent;
        uint256 denominator = valueOfDscMints * FRACTION_REMOVAL_MULTIPLIER;
        if (denominator >= numerator) {
            revert DSCEngine__CannotBeLiquidated(userToLiquidate);
        }

        // liquidated user debt zeroed /////////////////////////////////////////////
        s_userToDscMints[userToLiquidate] = 0;
        for(uint256 i=0;i<s_allowedCollateralTokens.length;++i) {
            // liquidator redeems all collaterals //////////////////////////////////
            _redeemCollateral(
                userToLiquidate,
                msg.sender,
                s_allowedCollateralTokens[i],
                s_userToCollateralDeposits[userToLiquidate][s_allowedCollateralTokens[i]]);
            // liquidated user collateral deposits zeroed //////////////////////////
            delete s_userToCollateralDeposits[userToLiquidate][s_allowedCollateralTokens[i]];
        }
        emit Liquidated(userToLiquidate,valueOfDscMints,valueOfDeposits);
        // liquidator burns DSC tokens /////////////////////////////////////////////
        _burnDSC(msg.sender,userToLiquidate,valueOfDscMints);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Internal Functions *//////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     *  @notice getValueOfDepositsInUsd()
     *          utility function for retrieving the total value in USD of all deposits held by a given user.
     *          to protect the privacy of the user, this function is internal and view only.
     *  @dev    note that the output rounds off to the nearest dollar, ie: all decimals are truncated off.
     *          note also that this conversion is based on prices retrieved at the time of this call.
     *              this output should not be stored for later use as it may become stale but should
     *              be requested afresh when needed.
     */
    function getValueOfDepositsInUsd(address user) internal view returns (uint256 valueInUsd) 
    {
        // loop through all allowed collateral tokens
        for(uint256 i=0;i<s_allowedCollateralTokens.length;i++) {
            // obtain deposit amount held by user in each collateral token
            uint256 depositHeld = s_userToCollateralDeposits[user][s_allowedCollateralTokens[i]];
            if (depositHeld > 0) {
                // convert to USD value and add to return value
                valueInUsd += convertToUsd(s_allowedCollateralTokens[i],depositHeld);
            }
        }
        //return valueInUsd;    // redundant
    }

    /**
     *  @notice getValueOfDscMintsInUsd()
     *          utility function for retrieving the total value in USD of all minted DSC tokens held by a 
     *              given user.
     *          to protect the privacy of the user, this function is internal and view only.
     *          since DSC token is pegged 1:1 to USD, so the output is basically the amount of minted DSC 
     *              held by the user.
     */
    function getValueOfDscMintsInUsd(address user) internal view returns (uint256 valueInUsd) {
        // since DSC token is USD-pegged 1:1, no extra logic needed to convert DSC token amount to its equivalent USD value
        return s_userToDscMints[user];
    }

    /**
     *  @notice _redeemCollateral()
     *          a more generic redeem function, only for internal authorized callers
     *  @param  from    account from which deposited collateral is to be redeemed
     *  @param  to      account to which the redeemed collateral tokens are transferred to
     *  @param  collateralTokenAddress  collateral token contract address
     *  @param  requestedRedeemAmount  amount of collateral to requested for redemption
     *  @dev    checks performed:
     *              1. redeem amount is more than zero
     *              2. redemption is in allowed tokens
     *              3. sufficient balance exists in from user's collateral deposits
     *              4. from user's redeem limit is not breached with this redemption request
     *  @dev    zero user address checks not needed because ERC20 transfer() and transferFrom() 
     *          already perform these and will revert with appropriate reverts
     *  @dev    if all checks passed, then proceed to:
     *              1. record redemption (ie: change internal state)
     *              2. emit event
     *              3. perform the actual token transfer
     */
    function _redeemCollateral(
        address from,
        address to,
        address collateralTokenAddress,
        uint256 requestedRedeemAmount
        ) internal 
        moreThanZero(requestedRedeemAmount) 
        onlyAllowedTokens(collateralTokenAddress) 
        sufficientBalance(from,collateralTokenAddress,requestedRedeemAmount) 
        withinRedeemLimitSimple(from,collateralTokenAddress,requestedRedeemAmount) 
        nonReentrant 
    {
        // 1st update state and send emits
        s_userToCollateralDeposits[from][collateralTokenAddress] -= requestedRedeemAmount;
        emit CollateralRedeemed(from,collateralTokenAddress,requestedRedeemAmount);

        // then perform actual action to effect the state change
        IERC20(collateralTokenAddress).transfer(to,requestedRedeemAmount);
        //bool success = IERC20(collateralTokenAddress).transferFrom(address(this),to,requestedRedeemAmount);
        /*
        bool success = IERC20(collateralTokenAddress).transfer(to,requestedRedeemAmount);
        // will never hit
        if (!success) {
            revert DSCEngine__TransferFailed(address(this),to,collateralTokenAddress,requestedRedeemAmount);
        }
        */
    }

    /**
     *  @notice _burnDSC()
     *          a more generic burn function, only for internal authorized callers
     *  @param  dscFrom account from where the DSC tokens to be burned will be transferred from
     *  @param  onBehalfOf  account on whose behalf the DSC tokens will be burned
     *                      ie: the account whose debt will be paid down.
     *  @param  requestedBurnAmount  amount of dsc tokens to burn
     *  @dev    checks performed:
     *              1. burn amount is more than zero
     *              2. sufficient balance exists in dscFrom account
     *  @dev    zero user address checks not needed because ERC20 transfer() and transferFrom() 
     *          already perform these and will revert with appropriate reverts
     *  @dev    if all checks passed, then proceed to:
     *              1. record burn (ie: change internal state)
     *              2. emit event
     *              3. perform the token transfer from user to DSCEngine
     *              4. DSCEngine performs the actual burn
     */
    function _burnDSC(
        address dscFrom,
        address onBehalfOf,
        uint256 requestedBurnAmount
        ) internal 
        moreThanZero(requestedBurnAmount) 
        sufficientBalance(dscFrom,i_dscToken,requestedBurnAmount) 
        nonReentrant 
    {
        // 1st update state and send emits
        s_userToDscMints[onBehalfOf] -= requestedBurnAmount;
        emit DSCBurned(onBehalfOf,requestedBurnAmount);

        // then perform actual action to effect the state change
        // 1st transfer DSC to be burned from user to engine
        IERC20(i_dscToken).transferFrom(dscFrom,address(this),requestedBurnAmount);
        /*
        bool success = IERC20(i_dscToken).transferFrom(dscFrom,address(this),requestedBurnAmount);
        if (!success) {
            revert DSCEngine__TransferFailed(dscFrom,address(this),i_dscToken,requestedBurnAmount);
        }
        */
        // then have the engine burn the DSC
        DecentralizedStableCoin(i_dscToken).burn(requestedBurnAmount);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Public Utility Functions *////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     *  @notice convertFromTo()
     *          utility function for converting from 1 token to another
     *          this function will not accept dsc token. Conversion to/from dsc token is equivalent
     *              to conversion to/from USD since dsc is pegged 1:1 to USD. The 2 functions
     *              convertToUsd() and convertFromUsd() may be used instead.
     *  @dev    note that the output rounds off to the nearest unit, ie: all decimals are truncated off.
     *          note also that this conversion is based on prices retrieved at the time of this call.
     *              this output should not be stored for later use as it may become stale but should
     *              be requested afresh when needed.
     *  @dev    note that this function will not accept dsc token. Conversion to/from dsc token is equivalent
     *              to conversion to/from USD since dsc is pegged 1:1 to USD.
     */
    function convertFromTo(
        address fromToken,
        uint256 amount,
        address toToken
        ) public view 
        onlyAllowedTokens(fromToken) 
        onlyAllowedTokens(toToken) 
        returns (uint256) 
    {
        if (amount == 0) {
            return 0;
        }
        return convertToUsd(fromToken,amount) / convertToUsd(toToken,1);
    }

    /**
     *  @notice convertFromUsd()
     *          utility function for converting from USD to the specified token,
     *              ie: how much of the token can the given amount of USD buy
     *          this function will not accept dsc token, nor is it necessary since dsc is pegged
     *              1:1 to USD, ie: 1 USD buys 1 DSC.
     *  @dev    note that the output rounds off to the nearest unit, ie: all decimals are truncated off.
     *          note also that this conversion is based on prices retrieved at the time of this call.
     *              this output should not be stored for later use as it may become stale but should
     *              be requested afresh when needed.
     */
    function convertFromUsd(
        uint256 amountUsd,
        address toToken
        ) public view 
        onlyAllowedTokens(toToken) 
        returns (uint256) 
    {
        if (amountUsd == 0) {
            return 0;
        }
        return amountUsd / convertToUsd(toToken,1);
    }

    /**
     *  @notice convertToUsd()
     *          utility function for converting any given token amount into equivalent USD.
     *          this function will not accept dsc token, nor is it necessary since dsc is pegged
     *              1:1 to USD, ie: 1 DSC converts to 1 USD.
     *  @dev    note that the output rounds off to the nearest dollar, ie: all decimals are truncated off.
     *          note also that this conversion is based on prices retrieved at the time of this call.
     *              this output should not be stored for later use as it may become stale but should
     *              be requested afresh when needed.
     */
    function convertToUsd(
        address token, 
        uint256 amount) 
        public view 
        onlyAllowedTokens(token) 
        returns (uint256 valueInUsd)
    {
        if (amount == 0) {
            return 0;
        }
        // obtain price feed address
        address priceFeed = s_tokenToPriceFeed[token].priceFeed;
        // obtain token price from price feed
        (,int answer,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) {
            revert DSCEngine__DataFeedError(token,priceFeed,answer);
        }
        // multiply amount by token price and return value in USD
        //return uint256(answer) * amount;
        // Cyfrin Updraft says what Chainlink Data Feed returns is (price * decimal precision)
        //  where decimal precision is given for each feed under Dec column in price feed page.
        //  So according to Updraft, correct return value = (uint256(answer) * 1e10 * amount) / 1e18
        //  Why? Dunno.
        //  Ok so Updraft made it unnecessarily complicated.
        //  Basically Chainlink Price Feed returns: int answer = (actual price in USD) * (decimal precision)
        //  So to obtain value in USD for amountOfTokens:
        //      (answer * amountOfTokens) / (decimal precision)
        //  Since this expression must yield an integer, it means that this value is rounded off to 
        //  the nearest dollar, with the decimal values (ie: cents) being truncated off.
        uint256 decimalPrecision = 10**(AggregatorV3Interface(priceFeed).decimals());
        return (uint256(answer) * amount / decimalPrecision);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /* Getter Functions *////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function getFractionRemovalMultiplier() external pure returns (uint256) {
        return FRACTION_REMOVAL_MULTIPLIER;
    }
    function getDscTokenAddress() external view returns (address) {
        return i_dscToken;
    }
    function getThresholdLimitPercent() external view returns (uint256) {
        return i_thresholdLimitPercent;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // This function is UNSAFE as it returns the internal array s_allowedCollateralTokens by reference,
    //  allowing the array to be modified outside of this function or even outside of the contract.
    // From within this contract, functions can already directly access the s_allowedCollateralTokens 
    //  array with no additional safety concerns.
    // For externals, the safer way to access the contents of s_allowedCollateralTokens is to retrieve 
    //  its length via getAllowedCollateralTokensArrayLength(), and then access its elements 1 by 1 via
    //  getAllowedCollateralTokens(). The return values for these 2 functions are "pass-by-value" and 
    //  will not modify the contents of the actual private array s_allowedCollateralTokens.
    /*
    function getAllowedCollateralTokensArray() external view returns (uint256 arrayLength,address[] memory allowedTokensArray) {
        return (s_allowedCollateralTokens.length,s_allowedCollateralTokens);
    }
    */
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function getAllowedCollateralTokensArrayLength() external view returns (uint256) {
        return s_allowedCollateralTokens.length;
    }
    function getAllowedCollateralTokens(uint256 index) external view returns (address) 
    {
        if (index >= s_allowedCollateralTokens.length) {
            revert DSCEngine__OutOfArrayRange(s_allowedCollateralTokens.length-1,index);
        }
        return s_allowedCollateralTokens[index];
    }
    function getPriceFeed(address token) external view onlyAllowedTokens(token) returns (address,uint256) {
        return (s_tokenToPriceFeed[token].priceFeed,s_tokenToPriceFeed[token].precision);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Exposing these 2 functions to externals is a bad idea. Users' privacy should be protected.
    /*
    function getDepositHeld(address user,address token) external view onlyAllowedTokens(token) returns (uint256) {
        return s_userToCollateralDeposits[user][token];
    }
    function getMintHeld(address user) external view returns (uint256) {
        return s_userToDscMints[user];
    }
    */
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
     *  Test Scaffolding
     *  These wrapper functions expose internal functions for the purpose of testing them.
     *  This whole section should be removed when from the final deployment/production code.
     */
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function exposegetValueOfDepositsInUsd(address user) public view returns (uint256) {
        return getValueOfDepositsInUsd(user);
    }
    function exposegetValueOfDscMintsInUsd(address user) public view returns (uint256) {
        return getValueOfDscMintsInUsd(user);
    }
    function expose_redeemCollateral(
        address from,
        address to,
        address collateralTokenAddress,
        uint256 requestedRedeemAmount
        ) public {
            _redeemCollateral(from,to,collateralTokenAddress,requestedRedeemAmount);
        }
    function expose_burnDSC(
        address dscFrom,
        address onBehalfOf,
        uint256 requestedBurnAmount
        ) public {
            _burnDSC(dscFrom,onBehalfOf,requestedBurnAmount);
        }
}