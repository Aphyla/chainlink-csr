// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TokenHelper {
    error TokenHelperNativeTransferFailed();

    function transfer(address token, address to, uint256 amount) internal {
        if (amount == 0) return;

        if (token == address(0)) {
            transferNative(to, amount);
        } else {
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        }
    }

    function refundExcessNative(address to) internal {
        if (msg.value > 0) {
            uint256 balance = address(this).balance;
            if (balance > 0) transferNative(to, balance);
        }
    }

    function transferNative(address to, uint256 amount) internal {
        if (amount == 0) return;

        (bool success,) = to.call{value: amount}(new bytes(0));
        if (!success) revert TokenHelperNativeTransferFailed();
    }
}
