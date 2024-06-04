// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOracle} from "../interfaces/IOracle.sol";
import {IOraclePool} from "../interfaces/IOraclePool.sol";

contract OraclePool is Ownable2Step, IOraclePool {
    using SafeERC20 for IERC20;

    address public immutable override SENDER;

    address public immutable override BASE_TOKEN;
    address public immutable override QUOTE_TOKEN;

    IOracle private _oracle;
    uint96 private _fee;

    uint256 private _quoteReserves;

    modifier onlySender() {
        _checkSender();
        _;
    }

    constructor(address sender, address baseToken, address quoteToken, address oracle, uint96 fee, address initialOwner)
        Ownable(initialOwner)
    {
        SENDER = sender;

        BASE_TOKEN = baseToken;
        QUOTE_TOKEN = quoteToken;

        _setOracle(oracle);
        _setFee(fee);
    }

    function getOracle() external view override returns (address) {
        return address(_oracle);
    }

    function getFee() external view override returns (uint96) {
        return _fee;
    }

    function getQuoteReserves() external view override returns (uint256) {
        return _quoteReserves;
    }

    function setOracle(address oracle) external override onlyOwner {
        _setOracle(oracle);
    }

    function setFee(uint96 fee) external override onlyOwner {
        _setFee(fee);
    }

    function swap(address recipient, uint256 minBaseAmount) external override onlySender {
        uint256 quoteBalance = IERC20(QUOTE_TOKEN).balanceOf(address(this));

        uint256 quoteAmount = quoteBalance - _quoteReserves;
        uint256 quoteFee = quoteAmount * _fee / 1e18;

        uint256 price = _oracle.getLatestAnswer();
        uint256 baseAmount = (quoteAmount - quoteFee) * 1e18 / price;

        if (baseAmount < minBaseAmount) revert OraclePoolInsufficientBaseAmount(baseAmount, minBaseAmount);

        uint256 baseBalance = IERC20(BASE_TOKEN).balanceOf(address(this));
        if (baseAmount > baseBalance) revert OraclePoolInsufficientBaseReserves(baseAmount, baseBalance);

        _quoteReserves = quoteBalance;

        emit Swap(recipient, baseAmount, quoteAmount);

        IERC20(BASE_TOKEN).safeTransfer(recipient, baseAmount);
    }

    function sendQuoteToken() external override onlySender {
        uint256 quoteReserves = _quoteReserves;
        _quoteReserves = 0;

        IERC20(QUOTE_TOKEN).safeTransfer(SENDER, quoteReserves);
    }

    function sweep(address token, address recipient, uint256 amount) external override onlyOwner {
        emit Sweep(token, recipient, amount);

        IERC20(token).safeTransfer(recipient, amount);

        if (token == address(QUOTE_TOKEN)) _quoteReserves = IERC20(QUOTE_TOKEN).balanceOf(address(this));
    }

    function _checkSender() internal view {
        if (msg.sender != SENDER) revert OraclePoolUnauthorizedSender(msg.sender);
    }

    function _setOracle(address oracle) internal {
        if (oracle == address(0)) revert OraclePoolAddressZero();

        _oracle = IOracle(oracle);

        emit OracleUpdated(oracle);
    }

    function _setFee(uint96 fee) internal {
        if (fee > 1e18) revert OraclePoolFeeTooHigh();

        _fee = fee;

        emit FeeUpdated(fee);
    }
}
