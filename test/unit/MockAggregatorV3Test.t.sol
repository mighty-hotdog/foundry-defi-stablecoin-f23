// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {MockAggregatorV3} from "../mocks/MockAggregatorV3.sol";

/**
 *  @notice We will dispense with creating a separate deploy script for 
 *          MockAggregatorV3 and just deploy it direct in the test contract 
 *          setUp() function.
 */
contract MockAggregatorV3Test is Test, Script {
    MockAggregatorV3 public mock;

    /* Test Variables to check against */
    string private constant ENV_LABEL_TO_READ = "CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD";
    uint256 private constant priceFeedAnswer = 4000*1e8;    // 4,000 USD * 1e8
                                                            // where 1e8 = precision of Chainlink Price Feed for ETH/USD
    uint8 private constant priceFeedPrecision = 8;
    string private constant descriptionOfMockDatafeed = "MockAggregatorV3";
    uint256 private constant versionOfMockDataFeed = 3;
    
    /* Setup Function */
    function setUp() external {
        mock = new MockAggregatorV3(ENV_LABEL_TO_READ);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for constructor()
    ////////////////////////////////////////////////////////////////////
    function testEnvLabelToRead() external view {
        assert(vm.envInt(mock.s_envLabelToRead()) == int256(priceFeedAnswer));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for decimals()
    ////////////////////////////////////////////////////////////////////
    function testDecimals() external view {
        assert(mock.decimals() == priceFeedPrecision);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for description()
    ////////////////////////////////////////////////////////////////////
    function testDescription() external view {
        assert(keccak256(bytes(mock.description())) == keccak256(bytes(descriptionOfMockDatafeed)));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for version()
    ////////////////////////////////////////////////////////////////////
    function testVersion() external view {
        assert(mock.version() == versionOfMockDataFeed);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for getRoundData()
    ////////////////////////////////////////////////////////////////////
    function testGetRoundData(uint80 randomRoundId) external view {
        (uint256 roundId,int256 answer,,,) = mock.getRoundData(randomRoundId);
        assert((roundId == randomRoundId) && (answer == int256(priceFeedAnswer)));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for latestRoundData()
    ////////////////////////////////////////////////////////////////////
    function testLatestRoundData() external view {
        (,int256 answer,,,) = mock.latestRoundData();
        assert(answer == int256(priceFeedAnswer));
    }
}