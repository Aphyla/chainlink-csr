// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CustomReceiver} from "./CustomReceiver.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {CCIPBaseUpgradeable} from "../ccip/CCIPBaseUpgradeable.sol";

/**
 * @title LidoCustomReceiver Contract
 * @dev A contract that receives native tokens, deposits them into the Lido stETH contract and initiates the token cross-chain transfer.
 * This contract can be deployed directly or used as an implementation for a proxy contract (upgradable or not).
 */
contract LidoCustomReceiver is CustomReceiver {
    using SafeERC20 for IERC20;

    address public immutable WSTETH;

    /**
     * @dev Set the immutable value for {WSTETH}, {CCIP_ROUTER} and {WNATIVE} and set the initial admin role.
     */
    constructor(address wstEth, address wnative, address ccipRouter, address initialAdmin)
        CustomReceiver(wnative)
        CCIPBaseUpgradeable(ccipRouter)
    {
        WSTETH = wstEth;

        initialize(initialAdmin);
    }

    /**
     * @dev Initializes the CustomReceiver contract dependency and sets the initial admin role.
     */
    function initialize(address initialAdmin) public initializer {
        __CustomReceiver_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /**
     * @dev Deposits `amount` of native tokens into the stETH contract and returns the amount of wstETH received.
     */
    function _depositNative(uint256 amount) internal override returns (uint256) {
        uint256 balance = IERC20(WSTETH).balanceOf(address(this));

        TokenHelper.transferNative(WSTETH, amount);

        return IERC20(WSTETH).balanceOf(address(this)) - balance;
    }
}
