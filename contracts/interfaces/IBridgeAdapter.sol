// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeAdapter {
    function sendToken(uint64 destChainSelector, address recipient, uint256 amount, bytes memory feeData) external;
}
