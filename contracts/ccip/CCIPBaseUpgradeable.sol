// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

abstract contract CCIPBaseUpgradeable is AccessControlUpgradeable {
    error CCIPBaseOnlyCCIPRouter();

    address public immutable CCIP_ROUTER;

    function __CCIPBase_init() internal onlyInitializing {}

    function __CCIPBase_init_unchained() internal onlyInitializing {}

    constructor(address ccipRouter) {
        CCIP_ROUTER = ccipRouter;
    }
}
