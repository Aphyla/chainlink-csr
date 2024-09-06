// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IBridgeAdapter {
    error BridgeAdapterOnlyDelegatedByDelegator();
    error BridgeAdapterInvalidParameters();

    event BaseL1toL2MessageSent();
    event OptimismL1toL2MessageSent();
    event FraxFerryL1toL2MessageSent();
    event ArbitrumL1toL2MessageSent(bytes32 messageId);
    event CCIPMessageSent(bytes32 messageId);

    function sendToken(uint64 destChainSelector, address recipient, uint256 amount, bytes calldata feeData) external;
}
