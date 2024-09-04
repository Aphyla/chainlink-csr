// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CustomReceiver} from "./CustomReceiver.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {CCIPBaseUpgradeable} from "../ccip/CCIPBaseUpgradeable.sol";
import {IEigenpieStaking} from "../interfaces/IEigenpieStaking.sol";

/**
 * @title EigenpieCustomReceiver Contract
 * @dev A contract that receives native tokens, deposits them into the Eigenpie stETH contract and initiates the token cross-chain transfer.
 * This contract can be deployed directly or used as an implementation for a proxy contract (upgradable or not).
 */
contract EigenpieCustomReceiver is CustomReceiver {
    using SafeERC20 for IERC20;

    error EigenpieCustomReceiverInvalidParameters();

    address public constant PLATFORM_TOKEN_ADDRESS = 0xeFEfeFEfeFeFEFEFEfefeFeFefEfEfEfeFEFEFEf;

    address public immutable EGETH;
    address public immutable EGETH_STAKING;

    /**
     * @dev Set the immutable value for {EGETH}, {EGETH_STAKING}, {CCIP_ROUTER} and {WNATIVE}
     * and set the initial admin role.
     */
    constructor(address egEth, address egEthStaking, address wnative, address ccipRouter, address initialAdmin)
        CustomReceiver(wnative)
        CCIPBaseUpgradeable(ccipRouter)
    {
        if (egEth == address(0) || egEthStaking == address(0) || initialAdmin == address(0)) {
            revert CustomReceiverInvalidParameters();
        }

        EGETH = egEth;
        EGETH_STAKING = egEthStaking;

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
     * @dev Stakes `amount` of native tokens into the stETH contract and returns the amount of wstETH received.
     */
    function _stakeToken(uint256 amount) internal override returns (uint256) {
        uint256 balance = IERC20(EGETH).balanceOf(address(this));

        IEigenpieStaking(EGETH_STAKING).depositAsset{value: amount}(PLATFORM_TOKEN_ADDRESS, amount, 0, address(0));

        return IERC20(EGETH).balanceOf(address(this)) - balance;
    }
}
