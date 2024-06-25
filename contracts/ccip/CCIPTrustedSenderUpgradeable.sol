// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {CCIPSenderUpgradeable} from "./CCIPSenderUpgradeable.sol";
import {ICCIPTrustedSenderUpgradeable} from "../interfaces/ICCIPTrustedSenderUpgradeable.sol";

/**
 * @title CCIPTrustedSenderUpgradeable Contract
 * @dev The base contract for all CCIP sender contracts.
 * It provides the ability to send messages to the CCIP router using the `ccipSend` function.
 * Each message can contain zero, one, or multiple (token, amount) pairs.
 * Each chain can have zero or one receiver.
 */
abstract contract CCIPTrustedSenderUpgradeable is CCIPSenderUpgradeable, ICCIPTrustedSenderUpgradeable {
    /* @custom:storage-location erc72101:ccip-csr.storage.CCIPTrustedSender */
    struct CCIPTrustedSenderStorage {
        mapping(uint64 destChainSelector => bytes receiver) receivers;
    }

    // keccak256(abi.encode(uint256(keccak256("ccip-csr.storage.CCIPTrustedSender")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CCIPTrustedSenderStorageLocation =
        0x0c7e84f56285f1b5532fe17ac0ab4310ac3914a71fe91e1c6ec35a7f3d15de00;

    function _getCCIPTrustedSenderStorage() private pure returns (CCIPTrustedSenderStorage storage $) {
        assembly {
            $.slot := CCIPTrustedSenderStorageLocation
        }
    }

    function __CCIPTrustedSender_init() internal initializer {}

    function __CCIPTrustedSender_init_unchained() internal initializer {}

    /**
     * @dev Returns the receiver for the destination chain selector.
     */
    function getReceiver(uint64 destChainSelector) public view virtual override returns (bytes memory) {
        return _getCCIPTrustedSenderStorage().receivers[destChainSelector];
    }

    /**
     * @dev Sets the receiver for the destination chain selector.
     * If the destination chain is an EVM chain, the receiver should be encoded using `abi.encode(address)`.
     *
     * Requirements:
     *
     * - `msg.sender` must have the `DEFAULT_ADMIN_ROLE`.
     *
     * Emits a {ReceiverSet} event.
     */
    function setReceiver(uint64 destChainSelector, bytes memory receiver)
        public
        virtual
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setReceiver(destChainSelector, receiver);
    }

    /**
     * @dev Sets the receiver for the destination chain selector.
     * If the destination chain is an EVM chain, the receiver should be encoded using `abi.encode(address)`.
     *
     * Emits a {ReceiverSet} event.
     */
    function _setReceiver(uint64 destChainSelector, bytes memory receiver) internal virtual {
        CCIPTrustedSenderStorage storage $ = _getCCIPTrustedSenderStorage();

        $.receivers[destChainSelector] = receiver;

        emit ReceiverSet(destChainSelector, receiver);
    }

    /**
     * @dev Sends a message to the CCIP router.
     * The message will contain exactly one (token, amount) pair.
     * This function will calculate the exact fee required for the message and send it to the router.
     * The fee can be paid in LINK or native token.
     *
     * Requirements:
     *
     * - `amount` must be greater than 0.
     * - `destChainSelector` must be a supported chain.
     * - `maxFee` must be greater than or equal to the fee for the message.
     * - if `payInLink` is `true`, `msg.sender` must have approved the contract to transfer `maxFee` of LINK. Else,
     *   `msg.value` must be greater than or equal to the fee for the message.
     * - `msg.sender` must have approved the contract to transfer `amount` of `token`.
     */
    function _ccipSend(
        uint64 destChainSelector,
        address token,
        uint256 amount,
        bool payInLink,
        uint256 maxFee,
        uint256 gasLimit,
        bytes memory data
    ) internal virtual returns (bytes32) {
        if (amount == 0) revert CCIPTrustedSenderZeroAmount();

        bytes memory receiver = getReceiver(destChainSelector);
        if (receiver.length == 0) revert CCIPTrustedSenderUnsupportedChain(destChainSelector);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        return _ccipSendTo(destChainSelector, receiver, tokenAmounts, payInLink, maxFee, gasLimit, data);
    }
}
