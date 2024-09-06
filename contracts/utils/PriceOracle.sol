// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle Contract
 * @dev A contract that allows to get the price of a token in 1e18 scale (18 decimals) using a Chainlink Aggregator.
 * It is expected that the price oracle returns the price in 1e18 scale (18 decimals).
 */
contract PriceOracle is Ownable2Step, IPriceOracle {
    uint256 private constant PRECISION = 1e18;

    AggregatorV3Interface private _aggregator;
    bool private _isInverse;
    uint32 private _heartbeat;
    uint8 private _decimals;

    /**
     * @dev Sets the initial values for the Chainlink Aggregator, the inverse flag, the heartbeat and the owner.
     *
     * The `aggregator` address is the address of the Chainlink Aggregator contract.
     * The `isInverse` flag is true if the price is inverted (1 / price).
     * The `heartbeat` is the time in seconds after which the price is considered stale.
     * The `initialOwner` is the address of the initial owner.
     */
    constructor(address aggregator, bool isInverse, uint32 heartbeat, address initialOwner) Ownable(initialOwner) {
        _setAggregator(AggregatorV3Interface(aggregator), isInverse);
        _setHeartbeat(heartbeat);
    }

    /**
     * @dev Returns the address of the Chainlink Aggregator contract.
     */
    function getOracleParameters() public view virtual override returns (address, bool, uint32, uint8) {
        return (address(_aggregator), _isInverse, _heartbeat, _decimals);
    }

    /**
     * @dev Returns the latest answer from the Chainlink Aggregator.
     *
     * Requirements:
     *
     * - The Chainlink Aggregator must be set.
     * - The price returned must be greater than 0.
     * - The price must not be stale, i.e. the timestamp of the price must be within the heartbeat.
     */
    function getLatestAnswer() public view virtual override returns (uint256 answerScaled) {
        AggregatorV3Interface aggregator = _aggregator;
        if (address(aggregator) == address(0)) revert PriceOracleAggregatorNotSet();

        (, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();

        if (answer <= 0) revert PriceOracleInvalidPrice();
        if (block.timestamp > updatedAt + _heartbeat) revert PriceOracleStalePrice();

        answerScaled =
            _isInverse ? 10 ** (18 + _decimals) / uint256(answer) : uint256(answer) * PRECISION / 10 ** _decimals;

        if (answerScaled == 0) revert PriceOracleInvalidPrice();
    }

    /**
     * @dev Sets the Chainlink Aggregator, the inverse flag and emits an {AggregatorUpdated} event.
     * Will also set the decimals to the decimals of the aggregator.
     *
     * The `aggregator` address is the address of the Chainlink Aggregator contract.
     * The `isInverse` flag is true if the price is inverted (1 / price).
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner.
     *
     * Emits an {AggregatorUpdated} event.
     */
    function setAggregator(address aggregator, bool isInverse) public virtual override onlyOwner {
        _setAggregator(AggregatorV3Interface(aggregator), isInverse);
    }

    /**
     * @dev Sets the heartbeat and emits an {HeartbeatUpdated} event.
     *
     * The `heartbeat` is the time in seconds after which the price is considered stale.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner.
     *
     * Emits a {HeartbeatUpdated} event.
     */
    function setHeartbeat(uint32 heartbeat) public virtual override onlyOwner {
        _setHeartbeat(heartbeat);
    }

    /**
     * @dev Sets the Chainlink Aggregator, the inverse flag and the decimals.
     *
     * The `aggregator` address is the address of the Chainlink Aggregator contract.
     * The `isInverse` flag is true if the price is inverted (1 / price).
     *
     * Emits an {AggregatorUpdated} event.
     */
    function _setAggregator(AggregatorV3Interface aggregator, bool isInverse) internal virtual {
        _aggregator = aggregator;
        _isInverse = isInverse;
        _decimals = address(aggregator) == address(0) ? 0 : aggregator.decimals();

        emit AggregatorUpdated(address(aggregator), isInverse);
    }

    /**
     * @dev Sets the heartbeat.
     *
     * The `heartbeat` is the time in seconds after which the price is considered stale.
     *
     * Emits a {HeartbeatUpdated} event.
     */
    function _setHeartbeat(uint32 heartbeat) internal virtual {
        _heartbeat = heartbeat;

        emit HeartbeatUpdated(heartbeat);
    }
}
