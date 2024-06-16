// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 *  @title  MockAggregatorV3
 *  @notice This is a custom mock for the Chainlink AggregatorV3Interface
 *  @author Mighty_Hotdog
 *  @dev    It implements the function interfaces defined in AggregatorV3Interface.
 *          getRoundData() and latestRoundData() will always return the same values no matter the roundId
 */
contract MockAggregatorV3 {
  struct ConstructorParams {
    string description;
    uint256 version;
    uint8 decimals;
    int256 answer;
  }

  string public s_description;
  uint256 public s_version;
  uint8 public s_decimals;
  int256 public s_answer;

  bool public s_useAltAnswer;
  int256 public s_alternateAnswer;

  constructor(ConstructorParams memory input) {
    s_description = input.description;
    s_version = input.version;
    s_decimals = input.decimals;
    s_answer = input.answer;
    s_useAltAnswer = false;
  }

  function decimals() external view returns (uint8) {
    return s_decimals;
  }

  function description() external view returns (string memory) {
    return s_description;
  }

  function version() external view returns (uint256) {
    return s_version;
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
    if (s_useAltAnswer) {answer = s_alternateAnswer;}
    else {answer = s_answer;}
    return (
      _roundId,
      answer,
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
    if (s_useAltAnswer) {answer = s_alternateAnswer;}
    else {answer = s_answer;}
    return (
      uint80(1),
      answer,
      uint256(1111),
      uint256(2222),
      uint80(1)
    );
  }

  function useAltPriceTrue(int256 altPrice) external 
  {
    s_alternateAnswer = altPrice;
    s_useAltAnswer = true;
  }

  function useAltPriceFalse() external 
  {
    s_useAltAnswer = false;
  }
}