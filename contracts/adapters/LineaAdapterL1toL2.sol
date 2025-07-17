// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILineaTokenBridge} from "../interfaces/ILineaTokenBridge.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {BridgeAdapter} from "./BridgeAdapter.sol";

/**
 * @title LineaAdapterL1toL2 Contract
 * @dev A bridge adapter for sending tokens from L1 to L2 on Linea.
 */
contract LineaAdapterL1toL2 is BridgeAdapter {
    using SafeERC20 for IERC20;

    /* Error thrown when the fee amount is invalid */
    error LineaAdapterL1toL2InvalidFeeAmount(uint256 expectedFeeAmount, uint256 feeAmount);
    error LineaAdapterL1toL2InvalidFeeToken();
    error LineaAdapterL1toL2InvalidParameters();

    address public immutable TOKEN_BRIDGE;
    address public immutable TOKEN;

    /**
     * @dev Sets the immutable values for {TOKEN_BRIDGE}, {TOKEN} and {DELEGATOR}.
     *
     * The `tokenBridge` address is the address of the L1 Linea Token Bridge contract.
     * The `token` address is the address of the token contract.
     * The `delegator` address is the address of the delegator contract.
     */
    constructor(address tokenBridge, address token, address delegator) BridgeAdapter(delegator) {
        if (tokenBridge == address(0) || token == address(0)) revert LineaAdapterL1toL2InvalidParameters();

        TOKEN_BRIDGE = tokenBridge;
        TOKEN = token;
    }

    /**
     * @dev Sends `amount` of tokens to `to` with `feeData` to the L2 using the L1 Standard Bridge.
     *
     * Requirements:
     *
     * - The fee amount must be equal to the expected fee amount (always 0).
     */
    function _sendToken(uint64, address to, uint256 amount, bytes calldata feeData) internal override {
        (uint256 feeAmount, bool payInLink) = FeeCodec.decodeLineaL1toL2(feeData);

        if (payInLink) revert LineaAdapterL1toL2InvalidFeeToken();
        if (feeAmount != 0) revert LineaAdapterL1toL2InvalidFeeAmount(feeAmount, 0);

        IERC20(TOKEN).forceApprove(TOKEN_BRIDGE, amount);

        ILineaTokenBridge(TOKEN_BRIDGE).bridgeToken(TOKEN, amount, to);

        emit LineaL1toL2MessageSent();
    }
}
