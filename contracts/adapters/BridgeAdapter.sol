// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";

abstract contract BridgeAdapter is IBridgeAdapter {
    error BridgeAdapterOnlyDelegatedByDelegator();

    address public immutable DELEGATOR;

    modifier onlyDelegatedByDelegator() {
        if (address(this) != DELEGATOR) revert BridgeAdapterOnlyDelegatedByDelegator();
        _;
    }

    constructor(address delegator) {
        DELEGATOR = delegator;
    }

    function sendToken(address recipient, uint256 amount, bytes memory feeData)
        external
        override
        onlyDelegatedByDelegator
    {
        _sendToken(recipient, amount, feeData);
    }

    function _sendToken(address recipient, uint256 amount, bytes memory feeData) internal virtual;
}
