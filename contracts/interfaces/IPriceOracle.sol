// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOracle} from "./IOracle.sol";

interface IPriceOracle is IOracle {
    error PriceOracleInvalidPrice();
    error PriceOracleStalePrice();
    error PriceOracleNoAggregator();

    event AggregatorUpdated(address indexed aggregator, bool isInverse);
    event HeartbeatUpdated(uint32 heartbeat);

    function getOracleParameters() external view returns (address, bool, uint32, uint8);
    function setAggregator(address aggregator, bool isInverse) external;
    function setHeartbeat(uint32 heartbeat) external;
}
