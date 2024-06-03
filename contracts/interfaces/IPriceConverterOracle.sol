// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOracle} from "./IOracle.sol";

interface IPriceConverterOracle is IOracle {
    error PriceConverterOracleAddressZero();

    event BasePriceOracleUpdated(address basePriceOracle);
    event QuotePriceOracleUpdated(address quotePriceOracle);

    function getBasePriceOracle() external view returns (address);
    function getQuotePriceOracle() external view returns (address);
    function setBasePriceOracle(address basePriceOracle) external;
    function setQuotePriceOracle(address quotePriceOracle) external;
}
