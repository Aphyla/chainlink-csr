// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BridgeAdapter} from "./BridgeAdapter.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IOptimismL1ERC20TokenBridge} from "../interfaces/IOptimismL1ERC20TokenBridge.sol";

/**
 * @title OptimismLegacyAdapterL1toL2 Contract
 * @dev A bridge adapter for sending tokens from L1 to L2 on Optimism.
 */
contract OptimismLegacyAdapterL1toL2 is BridgeAdapter {
    using SafeERC20 for IERC20;

    /* Error thrown when the fee amount is invalid */
    error OptimismLegacyAdapterL1toL2InvalidFeeAmount(uint256 expectedFeeAmount, uint256 feeAmount);
    error OptimismLegacyAdapterL1toL2InvalidFeeToken();
    error OptimismLegacyAdapterL1toL2InvalidParameters();

    address public immutable L1_ERC20_BRIDGE;
    address public immutable L1_TOKEN;
    address public immutable L2_TOKEN;

    /**
     * @dev Sets the immutable values for {L1_ERC20_BRIDGE} and {DELEGATOR}.
     * The {L1_TOKEN} and {L2_TOKEN} are set to the L1 and L2 tokens using the L1 ERC20 bridge contract.
     *
     * The `l1ERC20Bridge` address is the address of the L1 ERC20 bridge contract.
     * The `delegator` address is the address of the delegator contract.
     */
    constructor(address l1ERC20Bridge, address delegator) BridgeAdapter(delegator) {
        if (l1ERC20Bridge == address(0)) revert OptimismLegacyAdapterL1toL2InvalidParameters();

        L1_ERC20_BRIDGE = l1ERC20Bridge;
        L1_TOKEN = IOptimismL1ERC20TokenBridge(l1ERC20Bridge).l1Token();
        L2_TOKEN = IOptimismL1ERC20TokenBridge(l1ERC20Bridge).l2Token();
    }

    /**
     * @dev Sends `amount` of tokens to `to` with `feeData` to the L2 using the L1 ERC20 bridge.
     *
     * Requirements:
     *
     * - The fee amount must be equal to the expected fee amount (always 0).
     */
    function _sendToken(uint64, address to, uint256 amount, bytes calldata feeData) internal override {
        (uint256 feeAmount, bool payInLink, uint32 l2Gas) = FeeCodec.decodeOptimismL1toL2(feeData);

        if (payInLink) revert OptimismLegacyAdapterL1toL2InvalidFeeToken();
        if (feeAmount != 0) revert OptimismLegacyAdapterL1toL2InvalidFeeAmount(feeAmount, 0);

        IERC20(L1_TOKEN).forceApprove(L1_ERC20_BRIDGE, amount);

        IOptimismL1ERC20TokenBridge(L1_ERC20_BRIDGE).depositERC20To(L1_TOKEN, L2_TOKEN, to, amount, l2Gas, new bytes(0));

        emit OptimismL1toL2MessageSent();
    }
}
