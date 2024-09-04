// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CustomReceiver} from "./CustomReceiver.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {CCIPBaseUpgradeable} from "../ccip/CCIPBaseUpgradeable.sol";
import {IFraxETHMinter} from "../interfaces/IFraxETHMinter.sol";

/**
 * @title FraxCustomReceiver Contract
 * @dev A contract that receives native tokens, deposits them into the Frax sfrxETH contract and initiates the token cross-chain transfer.
 * This contract can be deployed directly or used as an implementation for a proxy contract (upgradable or not).
 */
contract FraxCustomReceiver is CustomReceiver {
    using SafeERC20 for IERC20;

    error FraxCustomReceiverInvalidParameters();

    address public immutable SFRXETH;
    address public immutable FRXETH_MINTER;

    /**
     * @dev Set the immutable value for {SFRXETH}, {FRXETH_MINTER}, {CCIP_ROUTER} and {WNATIVE} and set the initial admin role.
     */
    constructor(address sfrxEth, address frxETHMinter, address wnative, address ccipRouter, address initialAdmin)
        CustomReceiver(wnative)
        CCIPBaseUpgradeable(ccipRouter)
    {
        if (sfrxEth == address(0) || frxETHMinter == address(0) || initialAdmin == address(0)) {
            revert CustomReceiverInvalidParameters();
        }

        SFRXETH = sfrxEth;
        FRXETH_MINTER = frxETHMinter;

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
     * @dev Stakes `amount` of native tokens into the sfrxETH contract and returns the amount of sfrxETH received.
     */
    function _stakeToken(uint256 amount) internal override returns (uint256) {
        return IFraxETHMinter(FRXETH_MINTER).submitAndDeposit{value: amount}(address(this));
    }
}
