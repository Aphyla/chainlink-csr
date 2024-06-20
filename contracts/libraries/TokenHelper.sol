// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenHelper Library
 * @dev A library for handling token transfers and native transfers.
 */
library TokenHelper {
    /* @dev Error thrown when a native transfer fails */
    error TokenHelperNativeTransferFailed();

    /**
     * @dev Transfers `amount` of `token` to `to`.
     * If `amount` is zero, it does nothing.
     * If `token` is the zero address, it transfers `amount` of native tokens to `to`.
     */
    function transfer(address token, address to, uint256 amount) internal {
        if (amount == 0) return;

        if (token == address(0)) {
            transferNative(to, amount);
        } else {
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        }
    }

    /**
     * @dev Refunds the excess native tokens to `to`.
     * The excess native tokens are the native tokens that are in the contract after the function has been executed.
     * This function should only be used in a contract that should not hold any native tokens after the function has been executed.
     */
    function refundExcessNative(address to) internal {
        if (msg.value > 0) {
            uint256 balance = address(this).balance;
            if (balance > 0) transferNative(to, balance);
        }
    }

    /**
     * @dev Transfers `amount` of native tokens to `to`.
     * If `amount` is zero, it does nothing.
     *
     * Requirements:
     *
     * - The native token transfer must not fail.
     */
    function transferNative(address to, uint256 amount) internal {
        if (amount == 0) return;

        (bool success,) = to.call{value: amount}(new bytes(0));
        if (!success) revert TokenHelperNativeTransferFailed();
    }
}
