// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOracle} from "../interfaces/IOracle.sol";
import {IOraclePool} from "../interfaces/IOraclePool.sol";

contract OraclePool is Ownable2Step, IOraclePool {
    using SafeERC20 for IERC20;

    address public immutable override SENDER;
    address public immutable override TOKEN_IN;
    address public immutable override TOKEN_OUT;

    IOracle private _oracle;
    uint96 private _fee;

    modifier onlySender() {
        _checkSender();
        _;
    }

    constructor(address sender, address tokenIn, address tokenOut, address oracle, uint96 fee, address initialOwner)
        Ownable(initialOwner)
    {
        SENDER = sender;

        TOKEN_IN = tokenIn;
        TOKEN_OUT = tokenOut;

        _setOracle(IOracle(oracle));
        _setFee(fee);
    }

    function getOracle() external view override returns (address) {
        return address(_oracle);
    }

    function getFee() external view override returns (uint96) {
        return _fee;
    }

    function setOracle(address oracle) external override onlyOwner {
        _setOracle(IOracle(oracle));
    }

    function setFee(uint96 fee) external override onlyOwner {
        _setFee(fee);
    }

    function swap(address recipient, uint256 amountIn, uint256 minAmountOut)
        external
        override
        onlySender
        returns (uint256)
    {
        uint256 feeAmount = amountIn * _fee / 1e18;

        IOracle oracle = _oracle;
        if (address(oracle) == address(0)) revert OraclePoolNoOracle();

        uint256 price = oracle.getLatestAnswer();
        uint256 amountOut = (amountIn - feeAmount) * 1e18 / price;

        if (amountOut < minAmountOut) revert OraclePoolInsufficientAmountOut(amountOut, minAmountOut);

        uint256 availableOut = IERC20(TOKEN_OUT).balanceOf(address(this));
        if (amountOut > availableOut) revert OraclePoolInsufficientTokenOut(amountOut, availableOut);

        emit Swap(recipient, amountIn, amountOut);

        IERC20(TOKEN_OUT).safeTransfer(recipient, amountOut);

        return amountOut;
    }

    function pull(address token, uint256 amount) external override onlySender {
        if (token != TOKEN_IN) revert OraclePoolPullNotAllowed(token);

        uint256 available = IERC20(token).balanceOf(address(this));
        if (amount > available) revert OraclePoolInsufficientToken(token, amount, available);

        emit Pull(token, msg.sender, amount);

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function sweep(address token, address recipient, uint256 amount) external override onlyOwner {
        emit Sweep(token, recipient, amount);

        IERC20(token).safeTransfer(recipient, amount);
    }

    function _checkSender() internal view {
        if (msg.sender != SENDER) revert OraclePoolUnauthorizedAccount(msg.sender);
    }

    function _setOracle(IOracle oracle) internal {
        _oracle = oracle;

        emit OracleUpdated(address(oracle));
    }

    function _setFee(uint96 fee) internal {
        if (fee > 1e18) revert OraclePoolFeeTooHigh();

        _fee = fee;

        emit FeeUpdated(fee);
    }
}
