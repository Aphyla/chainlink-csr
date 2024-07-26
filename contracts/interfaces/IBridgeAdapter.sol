// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeAdapter {
    error BridgeAdapterOnlyDelegatedByDelegator();
    error BridgeAdapterInvalidDelegator();

    event OptimismL1toL2MessageSent();
    event ArbitrumL1toL2MessageSent(bytes32 messageId);
    event CCIPMessageSent(bytes32 messageId);

    function sendToken(uint64 destChainSelector, address recipient, uint256 amount, bytes memory feeData) external;
}
