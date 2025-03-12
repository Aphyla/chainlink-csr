// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {CustomSender} from "./CustomSender.sol";
import {ICustomSenderReferral, ICustomSender} from "../interfaces/ICustomSenderReferral.sol";

/**
 * @title CustomSenderReferral Contract
 * @dev The contract extends the CustomSender contract and adds the referral functionality to the fastStake function
 * by emitting a Referral event that can be used for tracking purposes off-chain.
 */
contract CustomSenderReferral is CustomSender, ICustomSenderReferral {
    /**
     * @dev Sets the immutable values for {TOKEN}, {WNATIVE}, {LINK_TOKEN}, and {CCIP_ROUTER} and the initial values for
     * the oracle pool and the admin role.
     */
    constructor(
        address token,
        address wnative,
        address linkToken,
        address ccipRouter,
        address oraclePool,
        address initialAdmin
    ) CustomSender(token, wnative, linkToken, ccipRouter, oraclePool, initialAdmin) {}

    /**
     * @dev Allows users to swap (W)Native for the native staked token using an oracle pool.
     * The user sends (W)Native to this contract, the oracle pool swaps the (W)Native for the native staked token,
     * and sends the native staked token back to the user.
     * The user can also specify a referral that is only used for tracking purposes.
     *
     * Requirements:
     *
     * - The amount sent must be greater than 0.
     * - The token sent must be the wrapped native token or native token.
     *
     * Emits a {FastStake} and {Referral} event.
     */
    function fastStakeReferral(address token, uint256 amount, uint256 minAmountOut, address referral)
        public
        payable
        override
        returns (uint256 amountOut)
    {
        amountOut = CustomSender.fastStake(token, amount, minAmountOut);
        emit Referral(msg.sender, referral, amountOut);
    }
}
