// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BridgeAdapter} from "./BridgeAdapter.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {CCIPSenderUpgradeable, Client, CCIPBaseUpgradeable} from "../ccip/CCIPSenderUpgradeable.sol";

/**
 * @title CCIPAdapter Contract
 * @dev A bridge adapter for sending tokens from L1 to L2 using CCIP.
 * This contract can only be used to pay fees in native token.
 * Any excess native token will be kept in the {DELEGATOR} contract.
 */
contract CCIPAdapter is BridgeAdapter, CCIPSenderUpgradeable {
    using SafeERC20 for IERC20;

    error CCIPAdapterInvalidParameters();

    address public immutable L1_TOKEN;

    /**
     * @dev Sets the immutable values for {L1_TOKEN}, {LINK_TOKEN}, {CCIP_ROUTER}, and {DELEGATOR}.
     * The {L1_TOKEN} is set to address(0) as this adapter only supports fees paid in native token.
     *
     * The `l1Token` address is the address of the L1 token contract.
     * The `linkToken` address is the address of the LINK token contract.
     * The `ccipRouter` address is the address of the CCIP router contract.
     * The `delegator` address is the address of the delegator contract.
     */
    constructor(address l1Token, address ccipRouter, address linkToken, address delegator)
        BridgeAdapter(delegator)
        CCIPSenderUpgradeable(linkToken)
        CCIPBaseUpgradeable(ccipRouter)
    {
        if (l1Token == address(0)) revert CCIPAdapterInvalidParameters();

        L1_TOKEN = l1Token;
    }

    /**
     * @dev Sends `amount` of tokens to `to` with `feeData` to the L2 using CCIP.
     *
     * Requirements:
     *
     * - The fee must be paid in native token.
     */
    function _sendToken(uint64 destChainSelector, address to, uint256 amount, bytes calldata feeData)
        internal
        override
    {
        (uint256 maxFee, bool payInLink, uint256 gasLimit) = FeeCodec.decodeCCIP(feeData);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: L1_TOKEN, amount: amount});

        bytes32 messageId = _ccipSendTo(
            destChainSelector, address(this), abi.encode(to), tokenAmounts, payInLink, maxFee, gasLimit, new bytes(0)
        );

        emit CCIPMessageSent(messageId);
    }
}
