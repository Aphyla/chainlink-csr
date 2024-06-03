// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

contract PriceOracle is Ownable2Step, IPriceOracle {
    AggregatorV3Interface private _aggregator;
    uint32 private _heartbeat;
    uint8 private _decimals;

    constructor(address aggregator, uint32 heartbeat, address initialOwner) Ownable(initialOwner) {
        _setAggregator(AggregatorV3Interface(aggregator));
        _setHeartbeat(heartbeat);
    }

    function getOracleParameters() external view override returns (address, uint32, uint8) {
        return (address(_aggregator), _heartbeat, _decimals);
    }

    function getLatestAnswer() external view override returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = _aggregator.latestRoundData();

        if (answer <= 0) revert OracleInvalidPrice();
        if (block.timestamp > updatedAt + _heartbeat) revert OracleStalePrice();

        return uint256(answer) * 1e18 / 10 ** _decimals;
    }

    function setAggregator(address aggregator) external override onlyOwner {
        _setAggregator(AggregatorV3Interface(aggregator));
    }

    function setHeartbeat(uint32 heartbeat) external override onlyOwner {
        _setHeartbeat(heartbeat);
    }

    function _setAggregator(AggregatorV3Interface aggregator) internal {
        _aggregator = aggregator;
        _decimals = aggregator.decimals();

        emit AggregatorUpdated(address(aggregator));
    }

    function _setHeartbeat(uint32 heartbeat) internal {
        _heartbeat = heartbeat;

        emit HeartbeatUpdated(heartbeat);
    }
}
