// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CustomReceiver} from "./CustomReceiver.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {CCIPBaseUpgradeable} from "../ccip/CCIPBaseUpgradeable.sol";

contract LidoCustomReceiver is CustomReceiver {
    using SafeERC20 for IERC20;

    address public immutable WSTETH;

    constructor(address wstEth, address wnative, address router, address initialAdmin)
        CustomReceiver(wnative)
        CCIPBaseUpgradeable(router)
    {
        WSTETH = wstEth;

        initialize(initialAdmin);
    }

    function initialize(address initialAdmin) public initializer {
        __CustomReceiver_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _depositNative(uint256 amount) internal override returns (uint256) {
        uint256 balance = IERC20(WSTETH).balanceOf(address(this));

        TokenHelper.transferNative(WSTETH, amount);

        return IERC20(WSTETH).balanceOf(address(this)) - balance;
    }
}
