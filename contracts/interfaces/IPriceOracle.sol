// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IOracle} from "./IOracle.sol";

interface IPriceOracle is IOracle {
    error PriceOracleInvalidPrice();
    error PriceOracleStalePrice();
    error PriceOracleAggregatorNotSet();

    event AggregatorUpdated(address indexed aggregator, bool isInverse);
    event HeartbeatUpdated(uint32 heartbeat);

    function getOracleParameters() external view returns (address, bool, uint32, uint8);
    function setAggregator(address aggregator, bool isInverse) external;
    function setHeartbeat(uint32 heartbeat) external;
}
