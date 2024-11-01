// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ICCIPTrustedSenderUpgradeable} from "./ICCIPTrustedSenderUpgradeable.sol";

interface ICustomSender is ICCIPTrustedSenderUpgradeable {
    error CustomSenderInsufficientNativeBalance(uint256 amount, uint256 balance);
    error CustomSenderInvalidToken();
    error CustomSenderOraclePoolNotSet();
    error CustomSenderZeroAmount();
    error CustomSenderInvalidParameters();
    error CustomSenderInsufficientGas();

    event OraclePoolSet(address oraclePool);
    event SlowStake(
        address indexed user, uint64 indexed destChainSelector, bytes32 messageId, address indexed token, uint256 amount
    );
    event FastStake(address indexed user, address indexed token, uint256 amountIn, uint256 amountOut);
    event Sync(address indexed user, uint64 indexed destChainSelector, bytes32 messageId, uint256 amount);

    function TOKEN() external view returns (address);
    function WNATIVE() external view returns (address);
    function SYNC_ROLE() external view returns (bytes32);
    function MIN_PROCESS_MESSAGE_GAS() external view returns (uint32);
    function getOraclePool() external view returns (address);
    function setOraclePool(address oraclePool) external;
    function slowStake(
        uint64 destChainSelector,
        address token,
        uint256 amount,
        bytes calldata feeOtoD,
        bytes calldata feeDtoO
    ) external payable returns (bytes32 messageId);
    function fastStake(address token, uint256 amount, uint256 minAmountOut)
        external
        payable
        returns (uint256 amountOut);
    function sync(uint64 destChainSelector, uint256 amount, bytes calldata feeOtoD, bytes calldata feeDtoO)
        external
        payable
        returns (bytes32 messageId);
}
