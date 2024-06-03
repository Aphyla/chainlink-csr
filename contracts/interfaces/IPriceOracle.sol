// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOracle} from "./IOracle.sol";

interface IPriceOracle is IOracle {
    error OracleInvalidPrice();
    error OracleStalePrice();

    event AggregatorUpdated(address indexed aggregator);
    event HeartbeatUpdated(uint32 heartbeat);

    function getOracleParameters() external view returns (address, uint32, uint8);
    function setAggregator(address aggregator) external;
    function setHeartbeat(uint32 heartbeat) external;
}
