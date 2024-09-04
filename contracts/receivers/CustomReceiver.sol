// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {CCIPDefensiveReceiverUpgradeable, Client} from "../ccip/CCIPDefensiveReceiverUpgradeable.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IWNative} from "../interfaces/IWNative.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {ICustomReceiver} from "../interfaces/ICustomReceiver.sol";

/**
 * @title CustomReceiver Contract
 * @dev A contract that receives native tokens, deposits them in the staking contract, and initiates the token cross-chain transfer.
 * The cross-chain token transfer is initiated using the adapter on the source chain for the destination chain.
 * This contract can be deployed directly or used as an implementation for a proxy contract (upgradable or not).
 *
 * The contract uses the EIP-7201 to prevent storage collisions.
 */
abstract contract CustomReceiver is CCIPDefensiveReceiverUpgradeable, ICustomReceiver {
    using SafeERC20 for IERC20;

    address public immutable WNATIVE;

    /* @custom:storage-location erc7201:ccip-csr.storage.CustomReceiver */
    struct CustomReceiverStorage {
        mapping(uint64 destChainSelector => address adapter) adapters;
    }

    // keccak256(abi.encode(uint256(keccak256("ccip-csr.storage.CustomReceiver")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CustomReceiverStorageLocation =
        0xe96b313a18d52f6e55cf90a558748e1da8588d7028d9f5f04c64b439a86c5400;

    function _getCustomReceiverStorage() private pure returns (CustomReceiverStorage storage $) {
        assembly {
            $.slot := CustomReceiverStorageLocation
        }
    }

    /**
     * @dev Set the immutable value for {WNATIVE}.
     */
    constructor(address wnative) {
        WNATIVE = wnative;
    }

    /**
     * @dev Initializes the CCIPDefensiveReceiverUpgradeable contract dependency.
     */
    function __CustomReceiver_init() internal onlyInitializing {
        __CCIPDefensiveReceiver_init();
    }

    function __CustomReceiver_init_unchained() internal onlyInitializing {}

    /**
     * @dev Allows the contract to receive native tokens.
     *
     * Requirements:
     *
     * - The caller must be the WNative contract.
     */
    receive() external payable virtual {
        if (msg.sender != WNATIVE) revert CustomReceiverOnlyWNative();
    }

    /**
     * @dev Returns the adapter for the destination chain selector.
     */
    function getAdapter(uint64 destChainSelector) public view virtual override returns (address) {
        return _getCustomReceiverStorage().adapters[destChainSelector];
    }

    /**
     * @dev Sets the adapter for the destination chain selector.
     *
     * Requirements:
     *
     * - `msg.sender` must have the `DEFAULT_ADMIN_ROLE`.
     *
     * Emits a {AdapterSet} event.
     */
    function setAdapter(uint64 destChainSelector, address adapter) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setAdapter(destChainSelector, adapter);
    }

    /**
     * @dev Sets the adapter for the destination chain selector.
     *
     * Emits a {AdapterSet} event.
     */
    function _setAdapter(uint64 destChainSelector, address adapter) internal virtual {
        CustomReceiverStorage storage $ = _getCustomReceiverStorage();

        $.adapters[destChainSelector] = adapter;

        emit AdapterSet(destChainSelector, adapter);
    }

    /**
     * @dev Processes the CCIP message.
     * Withdraws the native token, deposits the native token, and initiates the token cross-chain transfer using the adapter.
     *
     * Requirements:
     *
     * - The message must contain exactly one destination token amount.
     * - The destination token amount must be the native token.
     * - The native token amount must be equal to the amount plus the fee amount.
     */
    function _processMessage(Client.Any2EVMMessage calldata message) internal override {
        uint256 length = message.destTokenAmounts.length;
        if (length == 0 || length > 2) revert CustomReceiverInvalidTokenAmounts();

        (address recipient, uint256 amount, bytes calldata feeData) = FeeCodec.decodePackedData(message.data);

        uint256 tokenAmount = message.destTokenAmounts[0].amount;
        address token = message.destTokenAmounts[0].token;

        uint256 nativeAmount;

        if (length == 1) {
            (uint256 feeAmount,) = FeeCodec.decodeFee(feeData);
            uint256 total = amount + feeAmount;

            if (tokenAmount != total) revert CustomReceiverInvalidTokenAmount(tokenAmount, total);

            if (token == WNATIVE) nativeAmount = total;
        } else {
            uint256 expectedFeeAmount = message.destTokenAmounts[1].amount;

            (uint256 feeAmount, bool payInLink) = FeeCodec.decodeFee(feeData);

            if (tokenAmount != amount) revert CustomReceiverInvalidTokenAmount(tokenAmount, amount);
            if (feeAmount != expectedFeeAmount) revert CustomReceiverInvalidFeeAmount(feeAmount, expectedFeeAmount);

            nativeAmount = (token == WNATIVE ? amount : 0) + (payInLink ? 0 : feeAmount);
        }

        if (nativeAmount > 0) _unwrap(nativeAmount);

        uint256 staked = _stakeToken(amount);

        _sendToken(message.sourceChainSelector, recipient, staked, feeData);
    }

    /**
     * @dev Sends the token to the recipient using the adapter on the source chain.
     * Delegates the call to the adapter, which will handle the cross-chain token transfer.
     *
     * Requirements:
     *
     * - The adapter for the source chain selector must be set.
     */
    function _sendToken(uint64 sourceChainSelector, address recipient, uint256 amount, bytes calldata feeData)
        internal
        virtual
    {
        address adapter = getAdapter(sourceChainSelector);
        if (adapter == address(0)) revert CustomReceiverNoAdapter(sourceChainSelector);

        Address.functionDelegateCall(
            adapter,
            abi.encodeWithSelector(IBridgeAdapter.sendToken.selector, sourceChainSelector, recipient, amount, feeData)
        );
    }

    /**
     * @dev Unwraps the native token.
     */
    function _unwrap(uint256 amount) internal virtual {
        IWNative(WNATIVE).withdraw(amount);
    }

    /**
     * @dev Stakes the token in the staking contract.
     * Must return the amount received after depositing the token.
     */
    function _stakeToken(uint256 amount) internal virtual returns (uint256);
}
