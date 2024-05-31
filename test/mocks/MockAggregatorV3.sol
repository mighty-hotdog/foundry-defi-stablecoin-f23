// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

/**
 *  @title  MockAggregatorV3
 *  @notice This is a custom mock for the Chainlink AggregatorV3Interface
 *  @author Mighty_Hotdog
 *  @dev    It implements the function interfaces defined in AggregatorV3Interface.
 *          getRoundData() and latestRoundData() will always return the same values no matter the roundId
 */
contract MockAggregatorV3 is Script {
  string public s_envLabelToRead;

  constructor(string memory envLabelToRead) {
    s_envLabelToRead = envLabelToRead;
  }

  function decimals() external view returns (uint8) {
    return uint8(vm.envUint("CHAINLINK_MOCK_PRICE_FEED_PRECISION_ETH_USD"));
  }

  function description() external view returns (string memory) {
    //return "MockAggregatorV3";
    return vm.envString("CHAINLINK_MOCK_PRICE_FEED_DESCRIPTION");
  }

  function version() external view returns (uint256) {
    //return 3;
    return vm.envUint("CHAINLINK_MOCK_PRICE_FEED_VERSION");
  }

  function getRoundData(
    uint80 _roundId
  ) external view returns (
    uint80 roundId, 
    int256 answer, 
    uint256 startedAt, 
    uint256 updatedAt, 
    uint80 answeredInRound) 
    {
      return (
        _roundId,
        vm.envInt(s_envLabelToRead),
        uint256(1111),
        uint256(2222),
        uint80(1)
      );
    }

  function latestRoundData()
    external view returns (
        uint80 roundId, 
        int256 answer, 
        uint256 startedAt, 
        uint256 updatedAt, 
        uint80 answeredInRound)
    {
      return (
        uint80(1),
        vm.envInt(s_envLabelToRead),
        uint256(1111),
        uint256(2222),
        uint80(1)
      );
    }
}