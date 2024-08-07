// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBridgeAdapter {
    error BridgeAdapterOnlyDelegatedByDelegator();
    error BridgeAdapterInvalidDelegator();

    event BaseL1toL2MessageSent();
    event OptimismL1toL2MessageSent();
    event FraxFerryL1toL2MessageSent();
    event ArbitrumL1toL2MessageSent(bytes32 messageId);
    event CCIPMessageSent(bytes32 messageId);

    function sendToken(uint64 destChainSelector, address recipient, uint256 amount, bytes memory feeData) external;
}
