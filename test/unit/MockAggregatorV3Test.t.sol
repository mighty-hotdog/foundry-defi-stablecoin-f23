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
    MockAggregatorV3.ConstructorParams public params;

    /* Test Variables to check against */
    int256 private constant priceFeedAnswer = 4000*1e8;     // 4,000 USD * 1e8
                                                            // where 1e8 = precision of Chainlink Price Feed for ETH/USD
    uint8 private constant priceFeedPrecision = 8;
    string private constant descriptionOfMockDatafeed = "MockAggregatorV3";
    uint256 private constant versionOfMockDataFeed = 3;
    
    /* Setup Function */
    function setUp() external {
        mock = new MockAggregatorV3(
            MockAggregatorV3.ConstructorParams({
                description: vm.envString("CHAINLINK_MOCK_PRICE_FEED_DESCRIPTION"),
                version: vm.envUint("CHAINLINK_MOCK_PRICE_FEED_VERSION"),
                decimals: uint8(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD")),
                answer: vm.envInt("CHAINLINK_MOCK_PRICE_FEED_ANSWER_ETH_USD")
            }));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for constructor()
    // Skipped. Nothing to test.
    ////////////////////////////////////////////////////////////////////

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
        assert((roundId == randomRoundId) && (answer == priceFeedAnswer));
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for latestRoundData()
    ////////////////////////////////////////////////////////////////////
    function testLatestRoundData() external view {
        (,int256 answer,,,) = mock.latestRoundData();
        assert(answer == priceFeedAnswer);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for useAltPriceTrue()
    ////////////////////////////////////////////////////////////////////
    function testUseAltPriceTrue(int256 price) external {
        vm.assume(price != priceFeedAnswer);
        (,int256 answer,,,) = mock.latestRoundData();
        assert(answer == priceFeedAnswer);
        mock.useAltPriceTrue(price);
        (,answer,,,) = mock.latestRoundData();
        assert(answer == price);
    }

    ////////////////////////////////////////////////////////////////////
    // Unit tests for useAltPriceFalse()
    ////////////////////////////////////////////////////////////////////
    function testUseAltPriceFalse(int256 price) external {
        vm.assume(price != priceFeedAnswer);
        (,int256 answer,,,) = mock.latestRoundData();
        assert(answer == priceFeedAnswer);
        mock.useAltPriceTrue(price);
        (,answer,,,) = mock.latestRoundData();
        assert(answer == price);
        mock.useAltPriceFalse();
        (,answer,,,) = mock.latestRoundData();
        assert(answer == priceFeedAnswer);
    }
}