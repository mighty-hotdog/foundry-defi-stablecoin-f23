Building a stablecoin in this project.
1. Relative stability: Anchored* or Pegged -> 1.00 USD
    1. Chainlink price feeds
    2. Setup mechanism to exchange ETH & BTC -> USD
2. Stability mechanism (mint/burn): Algorithmic (Decentralized)
    1. new stablecoin can only be minted with enough collateral
3. Collateral: Exogenous (Crypto)
    1. wETH**
    2. wBTC**

*Ideal stablecoin is probably 1 that floats such that its purchase power tracks with
price of real world stuff. But floating stablecoin is much more difficult to design.

**Wrapped ETH and Wrapped BTC, ie: ERC20 compatible ETH and BTC. wETH is obtained by 
sending ETH to a conversion smart contract that issues/returns an equivalent amount 
of wETH. wBTC on the other hand is much less decentralized. Details below.

"wBTC is managed by a decentralized autonomous organization (DAO), which oversees the
system's operation. This governance model ensures transparency and security, with 
decisions about the system's future being made collectively by its members. Regular 
audits and proof-of-reserve transactions further enhance trust in the system by 
verifying that the Bitcoin backing wBTC exists and is secure" 
 - excerpt from https://www.gemini.com/cryptopedia/wbtc-what-is-wrapped-bitcoin

TODOs
1. ~write unit tests for MockAggregatorV3~  DONE
2. ~write integration tests for DeployDSCEngine~  DONE (but only tested on Anvil)
3. write unit/integration tests for DSCEngine
4. complete implementation for DSCEngine
5. complete tests for DSCEngine