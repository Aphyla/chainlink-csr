// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IOracle, IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceConverterOracle} from "../interfaces/IPriceConverterOracle.sol";

/**
 * @title PriceConverterOracle Contract
 * @dev A contract that allows to convert the price of a token from a base token to a quote token
 * using two price oracles.
 * It is expected that the price oracles return the price in 1e18 scale (18 decimals).
 * It is expected that the base price oracle returns the price of the base token in the quote token and
 * that the quote price oracle returns the price of the quote token in the base token. (A:B and B:C oracles)
 * For example, BTC:EUR and EUR:USD to get the price of BTC:USD.
 * The price returned is always in 1e18 scale (18 decimals) and is calculated as:
 * `price = basePriceOracle.getLatestAnswer() * quotePriceOracle.getLatestAnswer() / 1e18`
 */
contract PriceConverterOracle is Ownable2Step, IPriceConverterOracle {
    IPriceOracle private _basePriceOracle;
    IPriceOracle private _quotePriceOracle;

    /**
     * @dev Sets the initial values for the base price oracle, the quote price oracle and the owner.
     *
     * The `basePriceOracle` address is the address of the base price oracle contract.
     * The `quotePriceOracle` address is the address of the quote price oracle contract.
     * The `initialOwner` is the address of the initial owner.
     */
    constructor(address basePriceOracle, address quotePriceOracle, address initialOwner) Ownable(initialOwner) {
        _setBasePriceOracle(basePriceOracle);
        _setQuotePriceOracle(quotePriceOracle);
    }

    /**
     * @dev Returns the address of the base price oracle contract.
     */
    function getBasePriceOracle() public view virtual override returns (address) {
        return address(_basePriceOracle);
    }

    /**
     * @dev Returns the address of the quote price oracle contract.
     */
    function getQuotePriceOracle() public view virtual override returns (address) {
        return address(_quotePriceOracle);
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
        (IPriceOracle basePriceOracle, IPriceOracle quotePriceOracle) = (_basePriceOracle, _quotePriceOracle);

        if (address(basePriceOracle) == address(0) || address(quotePriceOracle) == address(0)) {
            revert PriceConverterOracleNoOracle();
        }

        answerScaled = _basePriceOracle.getLatestAnswer() * _quotePriceOracle.getLatestAnswer() / 1e18;

        if (answerScaled == 0) revert PriceConverterOracleInvalidPrice();
    }

    /**
     * @dev Sets the base price oracle address.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner.
     *
     * Emits a {BasePriceOracleUpdated} event.
     */
    function setBasePriceOracle(address basePriceOracle) public virtual override onlyOwner {
        _setBasePriceOracle(basePriceOracle);
    }

    /**
     * @dev Sets the quote price oracle address.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner.
     *
     * Emits a {QuotePriceOracleUpdated} event.
     */
    function setQuotePriceOracle(address quotePriceOracle) public virtual override onlyOwner {
        _setQuotePriceOracle(quotePriceOracle);
    }

    /**
     * @dev Sets the base price oracle address.
     *
     * Emits a {BasePriceOracleUpdated} event.
     */
    function _setBasePriceOracle(address basePriceOracle) internal virtual {
        _basePriceOracle = IPriceOracle(basePriceOracle);

        emit BasePriceOracleUpdated(basePriceOracle);
    }

    /**
     * @dev Sets the quote price oracle address.
     *
     * Emits a {QuotePriceOracleUpdated} event.
     */
    function _setQuotePriceOracle(address quotePriceOracle) internal virtual {
        _quotePriceOracle = IPriceOracle(quotePriceOracle);

        emit QuotePriceOracleUpdated(quotePriceOracle);
    }
}
