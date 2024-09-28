// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IOracle} from "./IOracle.sol";

interface IPriceConverterOracle is IOracle {
    error PriceConverterOracleInvalidParameters();
    error PriceConverterOracleInvalidPrice();

    function BASE_PRICE_ORACLE() external view returns (address);
    function QUOTE_PRICE_ORACLE() external view returns (address);
}
