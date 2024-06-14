// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockDataFeed {
    int256 internal _price;
    uint80 internal _roundId;
    uint256 internal _startedAt;
    uint256 internal _updatedAt;
    uint80 internal _answeredInRound;
    uint8 public decimals;

    constructor(uint8 _decimals) {
        decimals = _decimals;
    }

    function set(int256 price, uint80 roundId, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) external {
        _price = price;
        _roundId = roundId;
        _startedAt = startedAt;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _startedAt, _updatedAt, _answeredInRound);
    }
}
