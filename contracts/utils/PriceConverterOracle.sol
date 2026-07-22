// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IOracle, IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceConverterOracle} from "../interfaces/IPriceConverterOracle.sol";

/**
 * @title PriceConverterOracle Contract
 * @dev A contract that allows to convert the price of a token from a base token to a quote token
 * using two price oracles.
 * It is expected that the price oracles return the price in 1e18 scale (18 decimals).
 * It is expected that the base price oracle returns the price of the base token denominated in an
 * intermediate token (A:B) and that the quote price oracle returns the price of that intermediate token
 * denominated in the quote token (B:C).
 * For example, BTC:EUR (base) and EUR:USD (quote) to get the price of BTC:USD.
 * The price returned is always in 1e18 scale (18 decimals) and is calculated as:
 * `price = basePriceOracle.getLatestAnswer() * quotePriceOracle.getLatestAnswer() / 1e18`
 *
 * Accepted assumption: the two oracle answers are read independently and their update timestamps are not
 * reconciled. Each leg only enforces its own heartbeat, so the combined price may mix prices observed at
 * different points in time, bounded by the heartbeat of each leg.
 */
contract PriceConverterOracle is IPriceConverterOracle {
    uint256 private constant PRECISION = 1e18;

    address public immutable override BASE_PRICE_ORACLE;
    address public immutable override QUOTE_PRICE_ORACLE;

    /**
     * @dev Sets the immutable values for {BASE_PRICE_ORACLE} and {QUOTE_PRICE_ORACLE}.
     *
     * The `basePriceOracle` address is the address of the base price oracle contract.
     * The `quotePriceOracle` address is the address of the quote price oracle contract.
     */
    constructor(address basePriceOracle, address quotePriceOracle) {
        if (basePriceOracle == address(0) || quotePriceOracle == address(0)) {
            revert PriceConverterOracleInvalidParameters();
        }

        BASE_PRICE_ORACLE = basePriceOracle;
        QUOTE_PRICE_ORACLE = quotePriceOracle;
    }

    /**
     * @dev Returns the latest answer from the price oracles.
     *
     * Requirements:
     *
     * - Both price oracles must be set.
     * - The price returned must be greater than 0.
     */
    function getLatestAnswer() public view virtual override returns (uint256 answerScaled) {
        answerScaled = IPriceOracle(BASE_PRICE_ORACLE).getLatestAnswer()
            * IPriceOracle(QUOTE_PRICE_ORACLE).getLatestAnswer() / PRECISION;

        if (answerScaled == 0) revert PriceConverterOracleInvalidPrice();
    }
}
