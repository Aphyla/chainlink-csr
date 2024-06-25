// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICCIPDefensiveReceiverUpgradeable} from "./ICCIPDefensiveReceiverUpgradeable.sol";

interface ICustomReceiver is ICCIPDefensiveReceiverUpgradeable {
    error CustomReceiverOnlyWNative();
    error CustomReceiverInvalidTokenAmounts();
    error CustomReceiverInvalidNativeAmount(uint256 wnativeAmount, uint256 amount, uint256 feeAmount);
    error CustomReceiverNoAdapter(uint64 destChainSelector);

    event AdapterSet(uint64 indexed destChainSelector, address adapter);

    function getAdapter(uint64 destChainSelector) external view returns (address);
    function setAdapter(uint64 destChainSelector, address adapter) external;
}