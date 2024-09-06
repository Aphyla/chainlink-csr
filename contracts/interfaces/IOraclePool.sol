// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IOraclePool {
    error OraclePoolUnauthorizedAccount(address sender);
    error OraclePoolInsufficientTokenOut(uint256 amountOut, uint256 availableOut);
    error OraclePoolInsufficientToken(address token, uint256 amountOut, uint256 availableOut);
    error OraclePoolInsufficientAmountOut(uint256 amountOut, uint256 minAmountOut);
    error OraclePoolPullNotAllowed(address token);
    error OraclePoolOracleNotSet();
    error OraclePoolFeeTooHigh();
    error OraclePoolZeroAmountIn();
    error OraclePoolInvalidParameters();

    event Swap(address recipient, uint256 amountIn, uint256 amountOut);
    event Pull(address token, address recipient, uint256 amount);
    event Sweep(address token, address recipient, uint256 amount);
    event OracleUpdated(address oracle);
    event FeeUpdated(uint96 fee);

    function SENDER() external view returns (address);
    function TOKEN_IN() external view returns (address);
    function TOKEN_OUT() external view returns (address);
    function getOracle() external view returns (address);
    function getFee() external view returns (uint96);
    function setOracle(address oracle) external;
    function setFee(uint96 fee) external;
    function swap(address recipient, uint256 amountIn, uint256 minAmountOut) external returns (uint256);
    function pull(address token, uint256 amount) external;
    function sweep(address token, address recipient, uint256 amount) external;
}
