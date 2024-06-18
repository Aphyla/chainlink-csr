// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CCIPSenderUpgradeable, CCIPBaseUpgradeable} from "../ccip/CCIPSenderUpgradeable.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IWNative} from "../interfaces/IWNative.sol";
import {IOraclePool} from "../interfaces/IOraclePool.sol";

contract CustomSender is CCIPSenderUpgradeable {
    using SafeERC20 for IERC20;

    error CustomSenderInsufficientNativeBalance(uint256 amount, uint256 balance);
    error CustomSenderInvalidToken();
    error CustomSenderOraclePoolNotSet();

    event OraclePoolSet(address oraclePool);
    event MessageSent(uint64 indexed destChainSelector, bytes32 messageId);

    bytes32 public constant SYNC_ROLE = keccak256("SYNC_ROLE");

    address public immutable WNATIVE;

    struct CustomSenderStorage {
        address oraclePool;
    }

    // keccak256(abi.encode(uint256(keccak256("ccip-csr.storage.CustomSender")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CustomSenderStorageLocation =
        0x8d7d6771bb1753c5a4765d77340d4f09d4dc8da64869871a1bdb7f28bcfa7400;

    function _getCustomSenderStorage() private pure returns (CustomSenderStorage storage $) {
        assembly {
            $.slot := CustomSenderStorageLocation
        }
    }

    constructor(address wnative, address linkToken, address ccipRouter, address oraclePool, address initialAdmin)
        CCIPSenderUpgradeable(linkToken)
        CCIPBaseUpgradeable(ccipRouter)
    {
        WNATIVE = wnative;

        initialize(oraclePool, initialAdmin);
    }

    function initialize(address oraclePool, address initialAdmin) public initializer {
        __CCIPSender_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _setOraclePool(oraclePool);

        IERC20(WNATIVE).forceApprove(CCIP_ROUTER, type(uint256).max);
    }

    function getOraclePool() public view returns (address) {
        return _getCustomSenderStorage().oraclePool;
    }

    function setOraclePool(address oraclePool) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setOraclePool(oraclePool);
    }

    function slowStake(
        uint64 destChainSelector,
        address token,
        uint256 amount,
        bytes calldata feeOtoD,
        bytes calldata feeDtoO
    ) external payable virtual {
        token = _wrapOrTransferFrom(token, msg.sender, address(this), amount);

        _ccipBuildAndSend(destChainSelector, msg.sender, token, amount, feeOtoD, feeDtoO);

        TokenHelper.refundExcessNative(msg.sender);
    }

    function fastStake(address token, uint256 amount, uint256 minAmountOut) external payable virtual {
        address oraclePool = _getCustomSenderStorage().oraclePool;
        if (oraclePool == address(0)) revert CustomSenderOraclePoolNotSet();

        if (_wrapOrTransferFrom(token, msg.sender, oraclePool, amount) != WNATIVE) revert CustomSenderInvalidToken();

        IOraclePool(oraclePool).swap(msg.sender, amount, minAmountOut);

        TokenHelper.refundExcessNative(msg.sender);
    }

    function sync(uint64 destChainSelector, uint256 amount, bytes calldata feeOtoD, bytes calldata feeDtoO)
        external
        payable
        virtual
        onlyRole(SYNC_ROLE)
    {
        address oraclePool = _getCustomSenderStorage().oraclePool;
        if (oraclePool == address(0)) revert CustomSenderOraclePoolNotSet();

        IOraclePool(oraclePool).pull(WNATIVE, amount);

        _ccipBuildAndSend(destChainSelector, oraclePool, WNATIVE, amount, feeOtoD, feeDtoO);

        TokenHelper.refundExcessNative(msg.sender);
    }

    function _setOraclePool(address oraclePool) internal virtual {
        CustomSenderStorage storage $ = _getCustomSenderStorage();

        $.oraclePool = oraclePool;

        emit OraclePoolSet(oraclePool);
    }

    function _wrapOrTransferFrom(address token, address user, address to, uint256 amount)
        internal
        virtual
        returns (address)
    {
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(user, to, amount);
        } else {
            token = WNATIVE;
            _wrapNative(amount);
            if (to != address(this)) IERC20(token).safeTransfer(to, amount);
        }
        return token;
    }

    function _wrapNative(uint256 amount) internal virtual {
        uint256 nativeBalance = address(this).balance;
        if (amount > nativeBalance) revert CustomSenderInsufficientNativeBalance(amount, nativeBalance);

        IWNative(WNATIVE).deposit{value: amount}();
    }

    function _ccipBuildAndSend(
        uint64 destChainSelector,
        address recipient,
        address token,
        uint256 amount,
        bytes calldata feeOtoD,
        bytes calldata feeDtoO
    ) internal virtual returns (bytes32 messageId) {
        if (token != WNATIVE) revert CustomSenderInvalidToken();

        (uint256 maxFeeOtoD, bool payInLinkOtoD, uint256 gasLimitOtoD) = FeeCodec.decodeCCIP(feeOtoD);
        uint256 feeAmountDtoO = FeeCodec.decodeFee(feeDtoO);

        _wrapNative(feeAmountDtoO);

        bytes memory packedData = FeeCodec.encodePackedData(recipient, amount, feeDtoO);

        messageId = _ccipSend(
            destChainSelector, token, amount + feeAmountDtoO, payInLinkOtoD, maxFeeOtoD, gasLimitOtoD, packedData
        );

        emit MessageSent(destChainSelector, messageId);
    }
}
