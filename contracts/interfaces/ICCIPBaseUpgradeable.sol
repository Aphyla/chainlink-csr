// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ICCIPBaseUpgradeable is IERC165 {
    error CCIPBaseInvalidParameters();

    function CCIP_ROUTER() external view returns (address);
}
