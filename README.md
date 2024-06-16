# Foundry Defi Stablecoin

# About
This project creates a stablecoin with these properties:
1. Relative stability: Anchored or Pegged to 1.00 USD
2. Stability mechanism: Algorithmic (Decentralized)
3. Collateral: Exogenous (wETH and wBTC)

# Getting Started
## Requirements
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [foundry](https://getfoundry.sh/)

Installation
'sudo apt install git-all
`curl -L https://foundry.paradigm.xyz | bash

Depending on your Linux distribution, it could also be:
'sudo dnf install git-all
`curl -L https://foundry.paradigm.xyz | bash

You know you already have them installed correctly if you run:
* `git --version` and get a response `git version x.x.x`
* `forge --version` and get a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart
'git clone https://github.com/saracen75/foundry-defi-stablecoin-f23
`cd foundry-defi-stablecoin-f23
`forge build

## Testing
A word about the tests setup. Almost every test is a fuzz-test with random input variables. They are however stateless fuzz tests. No invariant tests are included in this repo.
Also, the `runs` are set to 1000 in the `foundry.toml`. Modify as you see fit.

## Code Libraries
This project uses [forge-std](https://github.com/foundry-rs/forge-std), [Chainlink Brownie Contracts](https://github.com/smartcontractkit/chainlink-brownie-contracts), [Openzeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts).

Installation
`forge install foundry-rs/forge-std --no-commit
`forge install smartcontractkit/chainlink-brownie-contracts --no-commit
`forge install OpenZeppelin/openzeppelin-contracts --no-commit

Then, update your `foundry.toml file`.
`remappings = [
`    '@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/src',
`    '@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/'
`]

# Stablecoin Mechanism
## Anchored or Pegged to 1.00 USD
The stablecoin's 1:1 peg to the USD is achieved via...developer decree (lol). But seriously, will have to study how real stablecoins like USDC actually maintain their peg.
*A better stablecoin is probably one with a floating value such that its purchase power tracks with the prices of real world stuff. But floating stablecoins are much more difficult to design and operate.*

## Stability mechanism: Algorithmic (Decentralized)
The stability mechanism relies on the decentralized decisions made by individual users to deposit new collaterals, mint more stablecoins, burn exist stablecoins, and/or liquidate other users.
* The system sets a threshold ratio to be maintained between the value of deposits and mints in a user's account.
* A user can only mint new stablecoins up to a limit determined by her deposits and this ratio.
* Each user maintains this ratio for her account through the following actions:
    1. deposit fresh collaterals into the system.
    2. mint new stablecoins from the system.
    3. burn any existing stablecoins she holds.
* When this ratio is breached for a particular user account, the system provides a way and pays an incentive for other users to liquidate this user, thereby clearing the breach and resetting the user's account.

## Collateral: Exogenous (wETH and wBTC)
The system accepts only collaterals that are exogenous to the system.
* The system accepts only wrapped ETH (wETH)# and wrapped BTC (wBTC)# as collaterals.
*Wrapped ETH and Wrapped BTC refers to ERC20-compatible ETH and BTC. wETH is obtained by sending ETH to a conversion smart contract that issues/returns an equivalent amount of wETH. wBTC on the other hand is much less decentralized.*
* Users have to deposit these tokens in sufficient amounts as collaterals to be able to mint new stablecoins.
* Chainlink price feeds are referenced for the latest price of these tokens.

>wBTC is managed by a decentralized autonomous organization (DAO), which oversees the
>system's operation. This governance model ensures transparency and security, with 
>decisions about the system's future being made collectively by its members. Regular 
>audits and proof-of-reserve transactions further enhance trust in the system by 
>verifying that the Bitcoin backing wBTC exists and is secure.
-excerpt from https://www.gemini.com/cryptopedia/wbtc-what-is-wrapped-bitcoin

# Final Part of the Course
Cyfrin Updraft explores advanced fuzz-testing and oracles management in the last part 
of this course.

## Fuzz Testing in Foundry:
### Stateless fuzz testing
Purpose is to surface bugs by throwing large numbers of random inputs at the functions to be tested and seeing which inputs break them.

Involves:
* Randomized input parameters to test functions.
* The Foundry tester goes thru each test function one by one, 1st running setUp() and then that test function.

### Stateful fuzz testing aka Invariant testing
Another level up from Stateless Fuzzing. Not just throwing random inputs at the functions but to also call the functions in random sequences, while maintaining state across each function call.

Involves:
* Identifying/defining a set of system invariants, then implementing each invariant into a test function with the "invariant" prefix, all in an "invariant test" contract.
*For eg: invariant_name_of_test()*
* Configuring the invariant tests in the foundry.toml: "runs", "depth" and "fail-on-revert".
* Setting the targets for the invariant testing:
    * target contracts
    * target senders
    * target interfaces
    * target selectors
    * target artifacts
    * target artifact selectors
* 2 types of Invariant Testing: Open testing and Handler-based testing.

#### Open-testing
* Set the unit test contracts as the target.
* The Foundry tester goes through each target contract, and for each run, based on configuration, chain-calls the test functions in random sequences, with state persisted across function calls.

#### Handler-based testing
* Define/implement the handler contracts and set these as the target contracts.
* In these handler contracts, define handler test functions that perform all prerequisites needed for the actual unit test functions not to revert when called, before calling of these test functions themselves.
* The Foundry tester goes thru each target handler contract, and for each run, based on configuration, calls These handler functions in random sequence, with state persisted across function calls. Every invariant test function is called after **each** handler test function call.

## Oracles Management
Oracles do break at times. It is important that our systems that rely on them do not also break when they do.

This is done by replacing the oracle price query call with a proxy function we define. This proxy function makes the same query call to the oracle, then checks the reply for staleness by comparing the updated-at time with the current block time. If the interval is greater than the refresh rates defined and published by the oracle itself, then the reply is stale. In this case, the proxy function reverts.

According to the Cyfrin Updraft course, the stablecoin system should be disabled at this point to prevent users from being harmed/exploited. The course leaves the rather serious issue of users having their funds locked up in the system as a challenge for students to try and solve. Gotta think abit more on that one...

If the reply is found to be not stale, the proxy function passes the reply back out to the caller.

# Learnings and Takeaways
Wrote alot of Solidity. Learned a ton doing this course.
* Learned alot about the features, and the ins and outs of Solidity itself.
* Encountered several issues like the "stack too deep" compiler error and how to fix them (ie: with variables scoping and collecting variables into structs).
* Learned alot about Foundry and its suite of tools.
* Explored the Openzeppelin, Chainlink Toolkit, Chainlink Brownie Contracts, and several other code libraries.
* Became more familiar with how blockchains and smart contracts work, particularly the EVM.
*eg: storage stacking, addresses, transactions, accounts, signing, cryptography and hashing, how value is sent through the blockchain, and a ton more stuff.*
* Introduced to several important EIPs and ERCs.
* Introduced to several tools and platforms useful for web3 developers and security auditors.
* Gained a rudimentary grasp of smart contracts security.

# Outstanding Tasks
1. Final bit of the tests for liquidate().
2. Update the deploy scripts.
3. Do up the Makefile, especially for:
    * deployment onchain
    * easy test deployment and tests running
    * using tools like Slither, SMT Checker, etc
4. Update the .env file with testing and deployment accounts info, eg: SEPOLIA_TESTNET_KEY_SENDER, PASSWORD_FILE