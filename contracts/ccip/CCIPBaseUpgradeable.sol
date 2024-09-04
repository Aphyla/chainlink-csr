// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {ICCIPBaseUpgradeable} from "../interfaces/ICCIPBaseUpgradeable.sol";

/**
 * @title CCIPBaseUpgradeable Contract
 * @dev The base contract for all CCIP contracts.
 */
abstract contract CCIPBaseUpgradeable is AccessControlUpgradeable, ICCIPBaseUpgradeable {
    address public immutable override CCIP_ROUTER;

    function __CCIPBase_init() internal onlyInitializing {}

    function __CCIPBase_init_unchained() internal onlyInitializing {}

    /**
     * @dev Sets the immutable values for the {CCIP_ROUTER} address.
     */
    constructor(address ccipRouter) {
        if (ccipRouter == address(0)) revert CCIPBaseInvalidParameters();

        CCIP_ROUTER = ccipRouter;
    }
}
