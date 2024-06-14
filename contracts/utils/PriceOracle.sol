// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

contract PriceOracle is Ownable2Step, IPriceOracle {
    AggregatorV3Interface private _aggregator;
    bool private _isInverse;
    uint32 private _heartbeat;
    uint8 private _decimals;

    constructor(address aggregator, bool isInverse, uint32 heartbeat, address initialOwner) Ownable(initialOwner) {
        _setAggregator(AggregatorV3Interface(aggregator), isInverse);
        _setHeartbeat(heartbeat);
    }

    function getOracleParameters() external view override returns (address, bool, uint32, uint8) {
        return (address(_aggregator), _isInverse, _heartbeat, _decimals);
    }

    function getLatestAnswer() external view override returns (uint256 answerScaled) {
        AggregatorV3Interface aggregator = _aggregator;
        if (address(aggregator) == address(0)) revert PriceOracleNoAggregator();

        (, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();

        if (answer <= 0) revert PriceOracleInvalidPrice();
        if (block.timestamp > updatedAt + _heartbeat) revert PriceOracleStalePrice();

        answerScaled = _isInverse ? 10 ** (18 + _decimals) / uint256(answer) : uint256(answer) * 1e18 / 10 ** _decimals;

        if (answerScaled == 0) revert PriceOracleInvalidPrice();
    }

    function setAggregator(address aggregator, bool isInverse) external override onlyOwner {
        _setAggregator(AggregatorV3Interface(aggregator), isInverse);
    }

    function setHeartbeat(uint32 heartbeat) external override onlyOwner {
        _setHeartbeat(heartbeat);
    }

    function _setAggregator(AggregatorV3Interface aggregator, bool isInverse) internal {
        _aggregator = aggregator;
        _isInverse = isInverse;
        _decimals = address(aggregator) == address(0) ? 0 : aggregator.decimals();

        emit AggregatorUpdated(address(aggregator), isInverse);
    }

    function _setHeartbeat(uint32 heartbeat) internal {
        _heartbeat = heartbeat;

        emit HeartbeatUpdated(heartbeat);
    }
}
