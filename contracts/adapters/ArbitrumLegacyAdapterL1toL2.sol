// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BridgeAdapter} from "./BridgeAdapter.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IArbitrumL1GatewayRouter} from "../interfaces/IArbitrumL1GatewayRouter.sol";

/**
 * @title ArbitrumLegacyAdapterL1toL2 Library
 * @dev An adapter for sending tokens from L1 to L2 on Arbitrum using the legacy L1 gateway.
 */
contract ArbitrumLegacyAdapterL1toL2 is BridgeAdapter {
    using SafeERC20 for IERC20;

    /* Error thrown when the fee amount is invalid */
    error ArbitrumLegacyAdapterL1toL2InvalidFeeToken();
    error ArbitrumLegacyAdapterInvalidParameters();

    address public immutable L1_GATEWAY_ROUTER;
    address public immutable L1_TOKEN;
    address public immutable L1_TOKEN_GATEWAY;

    /**
     * @dev Sets the immutable values for {L1_GATEWAY_ROUTER}, {L1_TOKEN} and {DELEGATOR}.
     * The {L1_TOKEN_GATEWAY} is set to the gateway contract for the L1 token using the L1 gateway router.
     *
     * The `l1GatewayRouter` address is the address of the L1 gateway router contract.
     * The `l1Token` address is the address of the L1 token contract.
     * The `delegator` address is the address of the delegator contract.
     */
    constructor(address l1GatewayRouter, address l1Token, address delegator) BridgeAdapter(delegator) {
        if (l1GatewayRouter == address(0) || l1Token == address(0)) revert ArbitrumLegacyAdapterInvalidParameters();

        L1_GATEWAY_ROUTER = l1GatewayRouter;
        L1_TOKEN = l1Token;
        L1_TOKEN_GATEWAY = IArbitrumL1GatewayRouter(l1GatewayRouter).l1TokenToGateway(l1Token);
    }

    /**
     * @dev Sends `amount` of tokens to `to` with `feeData` to the L2 using the L1 gateway router.
     *
     * Requirements:
     *
     * - The fee amount must be equal to the expected fee amount (maxSubmissionCost + gasPriceBid * maxGas).
     */
    function _sendToken(uint64, address to, uint256 amount, bytes calldata feeData) internal override {
        (uint256 feeAmount, bool payInLink, uint256 maxSubmissionCost, uint256 maxGas, uint256 gasPriceBid) =
            FeeCodec.decodeArbitrumL1toL2(feeData);

        if (payInLink) revert ArbitrumLegacyAdapterL1toL2InvalidFeeToken();

        IERC20(L1_TOKEN).forceApprove(L1_TOKEN_GATEWAY, amount);

        bytes memory messageId = IArbitrumL1GatewayRouter(L1_GATEWAY_ROUTER).outboundTransfer{value: feeAmount}(
            L1_TOKEN, to, amount, maxGas, gasPriceBid, abi.encode(maxSubmissionCost, new bytes(0))
        );

        emit ArbitrumL1toL2MessageSent(abi.decode(messageId, (bytes32)));
    }
}
