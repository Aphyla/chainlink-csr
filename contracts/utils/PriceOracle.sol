// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle Contract
 * @dev A contract that allows to get the price of a token in 1e18 scale (18 decimals) using a Chainlink Aggregator.
 * It is expected that the price oracle returns the price in 1e18 scale (18 decimals).
 */
contract PriceOracle is IPriceOracle {
    uint256 private constant PRECISION = 1e18;

    address public immutable AGGREGATOR;
    bool public immutable IS_INVERSE;
    uint8 public immutable DECIMALS;
    uint32 public immutable HEARTBEAT;

    /**
     * immutable values for {AGGREGATOR}, {IS_INVERSE}, {DECIMALS} and {HEARTBEAT}.
     *
     * The `aggregator` address is the address of the Chainlink Aggregator contract.
     * The `isInverse` flag is true if the price is inverted (1 / price).
     * The `heartbeat` is the time in seconds after which the price is considered stale.
     */
    constructor(address aggregator, bool isInverse, uint32 heartbeat) {
        if (aggregator == address(0)) revert PriceOracleInvalidParameters();

        AGGREGATOR = aggregator;
        IS_INVERSE = isInverse;
        DECIMALS = AggregatorV3Interface(aggregator).decimals();
        HEARTBEAT = heartbeat;
    }

    /**
     * @dev Returns the latest answer from the Chainlink Aggregator.
     *
     * Requirements:
     *
     * - The price returned must be greater than 0.
     * - The price must not be stale, i.e. the timestamp of the price must be within the heartbeat.
     */
    function getLatestAnswer() public view virtual override returns (uint256 answerScaled) {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(AGGREGATOR).latestRoundData();

        if (answer <= 0) revert PriceOracleInvalidPrice();
        if (block.timestamp > updatedAt + HEARTBEAT) revert PriceOracleStalePrice();

        answerScaled =
            IS_INVERSE ? 10 ** (18 + DECIMALS) / uint256(answer) : uint256(answer) * PRECISION / 10 ** DECIMALS;

        if (answerScaled == 0) revert PriceOracleInvalidPrice();
    }
}
