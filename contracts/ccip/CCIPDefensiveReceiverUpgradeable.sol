// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {CCIPBaseUpgradeable} from "./CCIPBaseUpgradeable.sol";

abstract contract CCIPDefensiveReceiverUpgradeable is
    CCIPBaseUpgradeable,
    ReentrancyGuardUpgradeable,
    IAny2EVMMessageReceiver
{
    using SafeERC20 for IERC20;

    error CCIPDefensiveReceiverOnlyCCIPRouter();
    error CCIPDefensiveReceiverOnlySelf();
    error CCIPDefensiveReceiverMessageNotFound(bytes32 messageId);
    error CCIPDefensiveReceiverMismatchedMessage(bytes32 messageId, bytes32 hash, bytes32 expectedHash);
    error CCIPDefensiveReceiverUnauthorizedSender(bytes sender, bytes expectedSender);
    error CCIPDefensiveReceiverUnsupportedChain(uint64 destChainSelector);

    event SenderSet(uint64 indexed destChainSelector, bytes sender);
    event MessageSucceeded(bytes32 indexed messageId);
    event MessageFailed(Client.Any2EVMMessage message, bytes error);
    event MessageRecovered(bytes32 indexed messageId);
    event TokensRecovered(bytes32 indexed messageId);

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

    modifier onlyRouter() {
        if (msg.sender != CCIP_ROUTER) revert CCIPDefensiveReceiverOnlyCCIPRouter();
        _;
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) revert CCIPDefensiveReceiverOnlySelf();
        _;
    }

    function __CCIPDefensiveReceiver_init() internal onlyInitializing {
        __ReentrancyGuard_init();
    }

    function __CCIPDefensiveReceiver_init_unchained() internal onlyInitializing {}

    function getSender(uint64 destChainSelector) public view virtual returns (bytes memory) {
        return _getCCIPDefensiveReceiverStorage().senders[destChainSelector];
    }

    function getFailedMessageHash(bytes32 messageId) public view returns (bytes32) {
        return _getCCIPDefensiveReceiverStorage().failedHashes[messageId];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function setSender(uint64 destChainSelector, bytes memory sender) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _setSender(destChainSelector, sender);
    }

    function retryFailedMessage(Client.Any2EVMMessage calldata message) external payable nonReentrant {
        _verifyAndMarkFailedMessage(message);
        _processMessage(message);

        emit MessageRecovered(message.messageId);
    }

    function recoverTokens(Client.Any2EVMMessage calldata message, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _verifyAndMarkFailedMessage(message);

        uint256 length = message.destTokenAmounts.length;
        for (uint256 i; i < length; ++i) {
            Client.EVMTokenAmount calldata tokenAmount = message.destTokenAmounts[i];
            IERC20(tokenAmount.token).safeTransfer(to, tokenAmount.amount);
        }

        emit TokensRecovered(message.messageId);
    }

    function processMessage(Client.Any2EVMMessage calldata message) external onlySelf {
        _processMessage(message);
    }

    function ccipReceive(Client.Any2EVMMessage calldata message) external override onlyRouter nonReentrant {
        _checkSender(message.sourceChainSelector, message.sender);

        try this.processMessage(message) {
            emit MessageSucceeded(message.messageId);
        } catch (bytes memory error) {
            _getCCIPDefensiveReceiverStorage().failedHashes[message.messageId] = keccak256(abi.encode(message));
            emit MessageFailed(message, error);
        }
    }

    function _checkSender(uint64 destChainSelector, bytes memory sender) internal view virtual {
        bytes memory expectedSender = getSender(destChainSelector);
        if (expectedSender.length == 0) revert CCIPDefensiveReceiverUnsupportedChain(destChainSelector);

        if (
            expectedSender.length <= 32 && sender.length <= 32
                ? bytes32(expectedSender) != bytes32(sender)
                : keccak256(expectedSender) != keccak256(sender)
        ) revert CCIPDefensiveReceiverUnauthorizedSender(sender, expectedSender);
    }

    function _verifyAndMarkFailedMessage(Client.Any2EVMMessage calldata message) internal virtual {
        CCIPDefensiveReceiverStorage storage $ = _getCCIPDefensiveReceiverStorage();

        bytes32 messageId = message.messageId;

        bytes32 expectedHash = $.failedHashes[messageId];
        if (expectedHash == 0) revert CCIPDefensiveReceiverMessageNotFound(messageId);

        bytes32 hash = keccak256(abi.encode(message));
        if (hash != expectedHash) revert CCIPDefensiveReceiverMismatchedMessage(messageId, hash, expectedHash);

        delete $.failedHashes[messageId];
    }

    function _setSender(uint64 destChainSelector, bytes memory sender) internal virtual {
        CCIPDefensiveReceiverStorage storage $ = _getCCIPDefensiveReceiverStorage();

        $.senders[destChainSelector] = sender;

        emit SenderSet(destChainSelector, sender);
    }

    function _processMessage(Client.Any2EVMMessage calldata message) internal virtual;
}
