// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {CCIPBaseUpgradeable, AccessControlUpgradeable} from "./CCIPBaseUpgradeable.sol";
import {ICCIPDefensiveReceiverUpgradeable} from "../interfaces/ICCIPDefensiveReceiverUpgradeable.sol";

/**
 * @title CCIPDefensiveReceiverUpgradeable Contract
 * @dev The base contract for all CCIP defensive receiver contracts.
 * It provides the ability to receive messages from the CCIP router and process them.
 * If the message fails, the contract will store the message hash to allow to retry it later.
 * If the message can't be retried, the owner can recover the tokens.
 *
 * The contract uses the EIP-7201 to prevent storage collisions.
 */
abstract contract CCIPDefensiveReceiverUpgradeable is
    CCIPBaseUpgradeable,
    ReentrancyGuardUpgradeable,
    ICCIPDefensiveReceiverUpgradeable
{
    using SafeERC20 for IERC20;

    /* @custom:storage-location erc72101:ccip-csr.storage.CCIPDefensiveReceiver */
    struct CCIPDefensiveReceiverStorage {
        mapping(uint64 destChainSelector => bytes sender) senders;
        mapping(bytes32 messageId => bytes32 hash) failedHashes;
    }

    // keccak256(abi.encode(uint256(keccak256("ccip-csr.storage.CCIPDefensiveReceiver")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CCIPDefensiveReceiverStorageLocation =
        0xf8229492f0149f33a386b5cb57d15282e2e432e70353863d88bdbe58ff07dc00;

    function _getCCIPDefensiveReceiverStorage() internal pure returns (CCIPDefensiveReceiverStorage storage $) {
        assembly {
            $.slot := CCIPDefensiveReceiverStorageLocation
        }
    }

    /**
     * @dev Modifier to check that the sender is the CCIP router.
     */
    modifier onlyCCIPRouter() {
        if (msg.sender != CCIP_ROUTER) revert CCIPDefensiveReceiverOnlyCCIPRouter();
        _;
    }

    /**
     * @dev Modifier to check that the sender is the contract itself.
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert CCIPDefensiveReceiverOnlySelf();
        _;
    }

    /**
     * @dev Initializes the ReentrancyGuard contract.
     */
    function __CCIPDefensiveReceiver_init() internal onlyInitializing {
        __ReentrancyGuard_init();
    }

    function __CCIPDefensiveReceiver_init_unchained() internal onlyInitializing {}

    /**
     * @dev Returns the sender for the destination chain.
     */
    function getSender(uint64 destChainSelector) public view virtual override returns (bytes memory) {
        return _getCCIPDefensiveReceiverStorage().senders[destChainSelector];
    }

    /**
     * @dev Returns the hash of the failed message. If the message doesn't exist, it will return 0.
     */
    function getFailedMessageHash(bytes32 messageId) public view override returns (bytes32) {
        return _getCCIPDefensiveReceiverStorage().failedHashes[messageId];
    }

    /**
     * @dev Checks if the contract supports the interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId
            || AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /**
     * @dev Sets the `sender` for the `destChainSelector` chain.
     * If the destination chain is an EVM, the `sender` should be encoded using `abi.encode(address)`.
     *
     * Requirements:
     *
     * - `msg.sender` must have the `DEFAULT_ADMIN_ROLE`.
     *
     * Emits a {SenderSet} event.
     */
    function setSender(uint64 destChainSelector, bytes memory sender)
        public
        virtual
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setSender(destChainSelector, sender);
    }

    /**
     * @dev Retries a failed message.
     *
     * Requirements:
     *
     * - The message must have failed.
     * - The message must not have been retried.
     * - The hash of `message` must match the stored hash.
     *
     * Emits a {MessageRecovered} event.
     */
    function retryFailedMessage(Client.Any2EVMMessage calldata message) external payable nonReentrant {
        _verifyAndMarkFailedMessage(message);
        _processMessage(message);

        emit MessageRecovered(message.messageId);
    }

    /**
     * @dev Recovers the tokens from a failed message and sends them to `to`.
     *
     * Requirements:
     *
     * - `msg.sender` must have the `DEFAULT_ADMIN_ROLE`.
     * - The message must have failed.
     * - The message must not have been retried.
     * - The hash of `message` must match the stored hash.
     *
     * Emits a {TokensRecovered} event.
     */
    function recoverTokens(Client.Any2EVMMessage calldata message, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _verifyAndMarkFailedMessage(message);

        uint256 length = message.destTokenAmounts.length;
        for (uint256 i; i < length; ++i) {
            Client.EVMTokenAmount calldata tokenAmount = message.destTokenAmounts[i];
            IERC20(tokenAmount.token).safeTransfer(to, tokenAmount.amount);
        }

        emit TokensRecovered(message.messageId);
    }

    /**
     * @dev Processes the message.
     *
     * Requirements:
     *
     * - Must be called by itself.
     *
     * Emits a {MessageSucceeded} event if the message is processed successfully.
     * Emits a {MessageFailed} event if the message fails.
     */
    function processMessage(Client.Any2EVMMessage calldata message) external onlySelf {
        _processMessage(message);
    }

    /**
     * @dev Receives the message from the CCIP router and processes it.
     *
     * Requirements:
     *
     * - The sender must be the expected sender.
     *
     * Emits a {MessageSucceeded} event if the message is processed successfully.
     * Emits a {MessageFailed} event if the message fails.
     */
    function ccipReceive(Client.Any2EVMMessage calldata message) external override onlyCCIPRouter nonReentrant {
        _checkSender(message.sourceChainSelector, message.sender);

        try this.processMessage(message) {
            emit MessageSucceeded(message.messageId);
        } catch (bytes memory error) {
            _getCCIPDefensiveReceiverStorage().failedHashes[message.messageId] = keccak256(abi.encode(message));
            emit MessageFailed(message, error);
        }
    }

    /**
     * @dev Checks if the sender is the expected sender.
     *
     * Requirements:
     *
     * - The `destChainSelector` must have a sender.
     * - The `sender` must match the expected sender.
     */
    function _checkSender(uint64 destChainSelector, bytes memory sender) internal view virtual {
        bytes memory expectedSender = getSender(destChainSelector);
        if (expectedSender.length == 0) revert CCIPDefensiveReceiverUnsupportedChain(destChainSelector);

        if (
            expectedSender.length <= 32 && sender.length <= 32
                ? bytes32(expectedSender) != bytes32(sender)
                : keccak256(expectedSender) != keccak256(sender)
        ) revert CCIPDefensiveReceiverUnauthorizedSender(sender, expectedSender);
    }

    /**
     * @dev Verifies the failed message and marks it as succeeded.
     *
     * Requirements:
     *
     * - The message must have failed.
     * - The hash of `message` must match the stored hash.
     */
    function _verifyAndMarkFailedMessage(Client.Any2EVMMessage calldata message) internal virtual {
        CCIPDefensiveReceiverStorage storage $ = _getCCIPDefensiveReceiverStorage();

        bytes32 messageId = message.messageId;

        bytes32 expectedHash = $.failedHashes[messageId];
        if (expectedHash == 0) revert CCIPDefensiveReceiverMessageNotFound(messageId);

        bytes32 hash = keccak256(abi.encode(message));
        if (hash != expectedHash) revert CCIPDefensiveReceiverMismatchedMessage(messageId, hash, expectedHash);

        delete $.failedHashes[messageId];
    }

    /**
     * @dev Sets the `sender` for the `destChainSelector` chain.
     *
     * Emits a {SenderSet} event.
     */
    function _setSender(uint64 destChainSelector, bytes memory sender) internal virtual {
        CCIPDefensiveReceiverStorage storage $ = _getCCIPDefensiveReceiverStorage();

        $.senders[destChainSelector] = sender;

        emit SenderSet(destChainSelector, sender);
    }

    /**
     * @dev Processes the message.
     */
    function _processMessage(Client.Any2EVMMessage calldata message) internal virtual;
}
