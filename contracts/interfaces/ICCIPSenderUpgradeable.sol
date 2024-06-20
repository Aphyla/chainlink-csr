// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICCIPBaseUpgradeable} from "./ICCIPBaseUpgradeable.sol";

interface ICCIPSenderUpgradeable is ICCIPBaseUpgradeable {
    error CCIPSenderUnsupportedChain(uint64 destChainSelector);
    error CCIPSenderZeroAmount();
    error CCIPSenderZeroAddress();
    error CCIPSenderExceedsMaxFee(uint256 fee, uint256 maxFee);

    event ReceiverSet(uint64 indexed destChainSelector, bytes receiver);

    function LINK_TOKEN() external view returns (address);
    function getReceiver(uint64 destChainSelector) external view returns (bytes memory);
    function setReceiver(uint64 destChainSelector, bytes memory receiver) external;
}
