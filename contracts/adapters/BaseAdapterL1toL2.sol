// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BridgeAdapter} from "./BridgeAdapter.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IBaseL1StandardBridge} from "../interfaces/IBaseL1StandardBridge.sol";

/**
 * @title BaseAdapterL1toL2 Contract
 * @dev A bridge adapter for sending tokens from L1 to L2 on Base.
 */
contract BaseAdapterL1toL2 is BridgeAdapter {
    using SafeERC20 for IERC20;

    /* Error thrown when the fee amount is invalid */
    error BaseAdapterL1toL2InvalidFeeAmount(uint256 expectedFeeAmount, uint256 feeAmount);

    address public immutable L1_STANDARD_BRIDGE;
    address public immutable L1_TOKEN;
    address public immutable L2_TOKEN;

    /**
     * @dev Sets the immutable values for {L1_STANDARD_BRIDGE}, {L1_TOKEN}, {L2_TOKEN}, and {DELEGATOR}.
     *
     * The `l1StandardBridge` address is the address of the L1 standard bridge contract.
     * The `l1Token` address is the address of the L1 token contract.
     * The `l2Token` address is the address of the L2 token contract.
     * The `delegator` address is the address of the delegator contract.
     */
    constructor(address l1StandardBridge, address l1Token, address l2Token, address delegator)
        BridgeAdapter(delegator)
    {
        L1_STANDARD_BRIDGE = l1StandardBridge;
        L1_TOKEN = l1Token;
        L2_TOKEN = l2Token;
    }

    /**
     * @dev Sends `amount` of tokens to `to` with `feeData` to the L2 using the L1 Standard Bridge.
     *
     * Requirements:
     *
     * - The fee amount must be equal to the expected fee amount (always 0).
     */
    function _sendToken(uint64, address to, uint256 amount, bytes memory feeData) internal override {
        (uint256 feeAmount, uint32 l2Gas) = FeeCodec.decodeBaseL1toL2(feeData);

        if (feeAmount != 0) revert BaseAdapterL1toL2InvalidFeeAmount(feeAmount, 0);

        IERC20(L1_TOKEN).forceApprove(L1_STANDARD_BRIDGE, amount);

        IBaseL1StandardBridge(L1_STANDARD_BRIDGE).depositERC20To(L1_TOKEN, L2_TOKEN, to, amount, l2Gas, new bytes(0));

        emit BaseL1toL2MessageSent();
    }
}
