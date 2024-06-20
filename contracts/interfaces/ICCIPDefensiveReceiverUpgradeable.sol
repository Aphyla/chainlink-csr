// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

import {ICCIPBaseUpgradeable} from "./ICCIPBaseUpgradeable.sol";

interface ICCIPDefensiveReceiverUpgradeable is ICCIPBaseUpgradeable, IAny2EVMMessageReceiver {
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

    function getFailedMessageHash(bytes32 messageId) external view returns (bytes32);
    function getSender(uint64 destChainSelector) external view returns (bytes memory);
    function processMessage(Client.Any2EVMMessage memory message) external;
    function recoverTokens(Client.Any2EVMMessage memory message, address to) external;
    function retryFailedMessage(Client.Any2EVMMessage memory message) external payable;
    function setSender(uint64 destChainSelector, bytes memory sender) external;
}
