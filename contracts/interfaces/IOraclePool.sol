// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOraclePool {
    error OraclePoolUnauthorizedAccount(address sender);
    error OraclePoolInsufficientBaseAmount(uint256 baseAmount, uint256 minBaseAmount);
    error OraclePoolInsufficientBaseReserves(uint256 baseAmount, uint256 baseBalance);
    error OraclePoolAddressZero();
    error OraclePoolFeeTooHigh();

    event Swap(address recipient, uint256 baseAmount, uint256 quoteAmount);
    event Sweep(address token, address recipient, uint256 amount);
    event OracleUpdated(address oracle);
    event FeeUpdated(uint96 fee);

    function SENDER() external view returns (address);
    function BASE_TOKEN() external view returns (address);
    function QUOTE_TOKEN() external view returns (address);
    function getOracle() external view returns (address);
    function getFee() external view returns (uint96);
    function getQuoteReserves() external view returns (uint256);
    function setOracle(address oracle) external;
    function setFee(uint96 fee) external;
    function swap(address recipient, uint256 minBaseAmount) external;
    function sendQuoteToken() external;
    function sweep(address token, address recipient, uint256 amount) external;
}
