// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BridgeAdapter} from "./BridgeAdapter.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IFraxFerry} from "../interfaces/IFraxFerry.sol";

/**
 * @title FraxFerryAdapterL1toL2 Contract
 * @dev A bridge adapter for sending Frax tokens from L1 to L2 using the Frax Ferry.
 */
contract FraxFerryAdapterL1toL2 is BridgeAdapter {
    using SafeERC20 for IERC20;

    /* Error thrown when the fee amount is invalid */
    error FraxFerryAdapterL1toL2InvalidFeeAmount(uint256 expectedFeeAmount, uint256 feeAmount);
    error FraxFerryAdapterL1toL2InvalidFeeToken();
    error FraxFerryAdapterL1toL2InvalidParameters();

    address public immutable FRAX_FERRY;
    address public immutable TOKEN;

    /**
     * @dev Sets the immutable values for {FRAX_FERRY}, {TOKEN} and {DELEGATOR}.
     *
     * The `fraxFerry` address is the address of the Frax Ferry contract.
     * The `delegator` address is the address of the delegator contract.
     */
    constructor(address fraxFerry, address token, address delegator) BridgeAdapter(delegator) {
        if (fraxFerry == address(0) || token == address(0)) revert FraxFerryAdapterL1toL2InvalidParameters();

        FRAX_FERRY = fraxFerry;
        TOKEN = token;
    }

    /**
     * @dev Sends `amount` of tokens to `to` with `feeData` to the L2 using the L1 Frax Ferry.
     *
     * Requirements:
     *
     * - The fee amount must be equal to the expected fee amount (always 0).
     */
    function _sendToken(uint64, address to, uint256 amount, bytes calldata feeData) internal override returns (address, uint256) {
        (uint256 feeAmount, bool payInLink) = FeeCodec.decodeFraxFerryL1toL2(feeData);

        if (payInLink) revert FraxFerryAdapterL1toL2InvalidFeeToken();
        if (feeAmount != 0) revert FraxFerryAdapterL1toL2InvalidFeeAmount(feeAmount, 0);

        IERC20(TOKEN).forceApprove(FRAX_FERRY, amount);

        IFraxFerry(FRAX_FERRY).embarkWithRecipient(amount, to);

        emit FraxFerryL1toL2MessageSent();

        return (address(0), 0);

    }
}
