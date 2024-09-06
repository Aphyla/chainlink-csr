// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ICCIPBaseUpgradeable} from "./ICCIPBaseUpgradeable.sol";

interface ICCIPSenderUpgradeable is ICCIPBaseUpgradeable {
    error CCIPSenderEmptyReceiver();
    error CCIPSenderInvalidTokenAmount();
    error CCIPSenderExceedsMaxFee(uint256 fee, uint256 maxFee);
    error CCIPSenderInvalidParameters();

    function LINK_TOKEN() external view returns (address);
}
