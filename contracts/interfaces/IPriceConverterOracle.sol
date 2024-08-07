// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOracle} from "./IOracle.sol";

interface IPriceConverterOracle is IOracle {
    error PriceConverterOracleNoOracle();
    error PriceConverterOracleInvalidPrice();

    event BasePriceOracleUpdated(address basePriceOracle);
    event QuotePriceOracleUpdated(address quotePriceOracle);

    function getBasePriceOracle() external view returns (address);
    function getQuotePriceOracle() external view returns (address);
    function setBasePriceOracle(address basePriceOracle) external;
    function setQuotePriceOracle(address quotePriceOracle) external;
}
