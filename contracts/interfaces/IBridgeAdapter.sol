// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeAdapter {
    function sendToken(address recipient, uint256 amount, bytes memory feeData) external;
}
