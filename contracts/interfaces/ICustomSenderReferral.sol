// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ICustomSender} from "./ICustomSender.sol";

interface ICustomSenderReferral is ICustomSender {
    event Referral(address indexed user, address indexed referral, uint256 amountOut);

    function fastStakeReferral(address token, uint256 amount, uint256 minAmountOut, address referral)
        external
        payable
        returns (uint256 amountOut);
}
