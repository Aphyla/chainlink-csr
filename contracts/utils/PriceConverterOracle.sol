// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IOracle, IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceConverterOracle} from "../interfaces/IPriceConverterOracle.sol";

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

    function getLatestAnswer() external view override returns (uint256) {
        return _basePriceOracle.getLatestAnswer() / _quotePriceOracle.getLatestAnswer();
    }

    function setBasePriceOracle(address basePriceOracle) external override onlyOwner {
        _setBasePriceOracle(basePriceOracle);
    }

    function setQuotePriceOracle(address quotePriceOracle) external override onlyOwner {
        _setQuotePriceOracle(quotePriceOracle);
    }

    function _setBasePriceOracle(address basePriceOracle) internal {
        if (basePriceOracle == address(0)) revert PriceConverterOracleAddressZero();

        _basePriceOracle = IPriceOracle(basePriceOracle);

        emit BasePriceOracleUpdated(basePriceOracle);
    }

    function _setQuotePriceOracle(address quotePriceOracle) internal {
        if (quotePriceOracle == address(0)) revert PriceConverterOracleAddressZero();

        _quotePriceOracle = IPriceOracle(quotePriceOracle);

        emit QuotePriceOracleUpdated(quotePriceOracle);
    }
}
