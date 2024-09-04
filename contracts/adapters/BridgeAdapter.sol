// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";

/**
 * @title BridgeAdapter Contract
 * @dev Abstract contract for bridge adapters.
 * Bridge adapters are contracts that are used to send tokens from one chain to another.
 * They are delegate called by the delegator contract to send tokens.
 * They must not use storage variables to prevent any storage collisions with the delegator contract.
 */
abstract contract BridgeAdapter is IBridgeAdapter {
    address public immutable DELEGATOR;

    /**
     * @dev Modifier to check that the function is delegate called by the delegator contract.
     */
    modifier onlyDelegatedByDelegator() {
        if (address(this) != DELEGATOR) revert BridgeAdapterOnlyDelegatedByDelegator();
        _;
    }

    /**
     * @dev Initializes the contract with the delegator address.
     * @param delegator The address of the delegator contract.
     */
    constructor(address delegator) {
        if (delegator == address(this)) revert BridgeAdapterInvalidDelegator();

        DELEGATOR = delegator;
    }

    /**
     * @dev Sends `amount` of tokens to `recipient` with `feeData`.
     *
     * Requirements:
     *
     * - The function must be delegate called by the delegator contract.
     */
    function sendToken(uint64 destChainSelector, address recipient, uint256 amount, bytes calldata feeData)
        external
        override
        onlyDelegatedByDelegator
    {
        _sendToken(destChainSelector, recipient, amount, feeData);
    }

    /**
     * @dev Internal function to send `amount` of tokens to `recipient` with `feeData`.
     */
    function _sendToken(uint64 destChainSelector, address recipient, uint256 amount, bytes calldata feeData)
        internal
        virtual;
}
