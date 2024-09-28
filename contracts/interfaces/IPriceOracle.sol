// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IOracle} from "./IOracle.sol";

interface IPriceOracle is IOracle {
    error PriceOracleInvalidPrice();
    error PriceOracleStalePrice();
    error PriceOracleInvalidParameters();

    function AGGREGATOR() external view returns (address);
    function IS_INVERSE() external view returns (bool);
    function DECIMALS() external view returns (uint8);
    function HEARTBEAT() external view returns (uint32);
}
