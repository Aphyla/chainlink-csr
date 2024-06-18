// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {CCIPDefensiveReceiverUpgradeable, Client} from "../ccip/CCIPDefensiveReceiverUpgradeable.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IWNative} from "../interfaces/IWNative.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";

abstract contract CustomReceiver is CCIPDefensiveReceiverUpgradeable {
    using SafeERC20 for IERC20;

    error CustomReceiverOnlyWNative();
    error CustomReceiverInvalidTokenAmounts();
    error CustomReceiverInvalidNativeAmount(uint256 wnativeAmount, uint256 amount, uint256 feeAmount);
    error CustomReceiverNoAdapter(uint64 destChainSelector);

    event AdapterSet(uint64 indexed destChainSelector, address adapter);

    address public immutable WNATIVE;

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

    constructor(address wnative) {
        WNATIVE = wnative;
    }

    function __CustomReceiver_init() internal initializer {
        __CCIPDefensiveReceiver_init();
    }

    function __CustomReceiver_init_unchained() internal initializer {}

    receive() external payable virtual {
        if (msg.sender != WNATIVE) revert CustomReceiverOnlyWNative();
    }

    function getAdapter(uint64 destChainSelector) public view virtual returns (address) {
        return _getCustomReceiverStorage().adapters[destChainSelector];
    }

    function setAdapter(uint64 destChainSelector, address adapter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setAdapter(destChainSelector, adapter);
    }

    function _setAdapter(uint64 destChainSelector, address adapter) internal virtual {
        CustomReceiverStorage storage $ = _getCustomReceiverStorage();

        $.adapters[destChainSelector] = adapter;

        emit AdapterSet(destChainSelector, adapter);
    }

    function _processMessage(Client.Any2EVMMessage calldata message) internal override {
        if (message.destTokenAmounts.length != 1 || message.destTokenAmounts[0].token != WNATIVE) {
            revert CustomReceiverInvalidTokenAmounts();
        }

        uint256 wnativeAmount = message.destTokenAmounts[0].amount;

        (address recipient, uint256 amount, bytes memory feeData) = FeeCodec.decodePackedData(message.data);
        uint256 feeAmount = FeeCodec.decodeFee(feeData);

        if (wnativeAmount != amount + feeAmount) {
            revert CustomReceiverInvalidNativeAmount(wnativeAmount, amount, feeAmount);
        }

        IWNative(WNATIVE).withdraw(wnativeAmount);
        uint256 toSend = _depositNative(amount);

        _sendToken(message.sourceChainSelector, recipient, toSend, feeData);
    }

    function _sendToken(uint64 sourceChainSelector, address recipient, uint256 amount, bytes memory feeData)
        internal
        virtual
    {
        address adapter = getAdapter(sourceChainSelector);
        if (adapter == address(0)) revert CustomReceiverNoAdapter(sourceChainSelector);

        Address.functionDelegateCall(
            adapter, abi.encodeWithSelector(IBridgeAdapter.sendToken.selector, recipient, amount, feeData)
        );
    }

    function _depositNative(uint256 amount) internal virtual returns (uint256);
}
