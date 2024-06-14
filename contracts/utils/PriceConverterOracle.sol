// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IOracle, IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceConverterOracle} from "../interfaces/IPriceConverterOracle.sol";

// Only for A:B and B:C price oracles, for example: BTC:USD and USD:ETH to get BTC:ETH
contract PriceConverterOracle is Ownable2Step, IPriceConverterOracle {
    IPriceOracle private _basePriceOracle;
    IPriceOracle private _quotePriceOracle;

    constructor(address basePriceOracle, address quotePriceOracle, address initialOwner) Ownable(initialOwner) {
        _setBasePriceOracle(basePriceOracle);
        _setQuotePriceOracle(quotePriceOracle);
    }

    function getBasePriceOracle() external view override returns (address) {
        return address(_basePriceOracle);
    }

    function getQuotePriceOracle() external view override returns (address) {
        return address(_quotePriceOracle);
    }

    function getLatestAnswer() external view override returns (uint256 answerScaled) {
        (IPriceOracle basePriceOracle, IPriceOracle quotePriceOracle) = (_basePriceOracle, _quotePriceOracle);

        if (address(basePriceOracle) == address(0) || address(quotePriceOracle) == address(0)) {
            revert PriceConverterOracleNoOracle();
        }

        answerScaled = _basePriceOracle.getLatestAnswer() * _quotePriceOracle.getLatestAnswer() / 1e18;

        if (answerScaled == 0) revert PriceConverterOracleInvalidPrice();
    }

    function setBasePriceOracle(address basePriceOracle) external override onlyOwner {
        _setBasePriceOracle(basePriceOracle);
    }

    function setQuotePriceOracle(address quotePriceOracle) external override onlyOwner {
        _setQuotePriceOracle(quotePriceOracle);
    }

    function _setBasePriceOracle(address basePriceOracle) internal {
        _basePriceOracle = IPriceOracle(basePriceOracle);

        emit BasePriceOracleUpdated(basePriceOracle);
    }

    function _setQuotePriceOracle(address quotePriceOracle) internal {
        _quotePriceOracle = IPriceOracle(quotePriceOracle);

        emit QuotePriceOracleUpdated(quotePriceOracle);
    }
}