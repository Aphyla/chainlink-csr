// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CCIPTrustedSenderUpgradeable, Client} from "../ccip/CCIPTrustedSenderUpgradeable.sol";
import {CCIPSenderUpgradeable, CCIPBaseUpgradeable} from "../ccip/CCIPSenderUpgradeable.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IWNative} from "../interfaces/IWNative.sol";
import {IOraclePool} from "../interfaces/IOraclePool.sol";
import {ICustomSender} from "../interfaces/ICustomSender.sol";

/**
 * @title CustomSender Contract
 * @dev A contract that allows users to stake (W)Native to receive a staked token that isn't native to this chain.
 * The slow staking function allows users to send (W)Native to the receiver contract on the main chain, mint the native staked
 * token and send it back to the user on this chain.
 * The fast staking function allows users to swap (W)Native for the native staked token using an oracle pool.
 * Then an operator can synchronize this chain by sending the native tokens to the receiver contract on the main chain,
 * mint the native staked token and send it back to the oracle pool on this chain.
 * This contract can be deployed directly or used as an implementation for a proxy contract (upgradable or not).
 *
 * The contract uses the EIP-7201 to prevent storage collisions.
 */
contract CustomSender is CCIPTrustedSenderUpgradeable, ICustomSender {
    using SafeERC20 for IERC20;

    /* The minimum gas to process the message. */
    uint32 public constant override MIN_PROCESS_MESSAGE_GAS = 75_000;

    bytes32 public constant override SYNC_ROLE = keccak256("SYNC_ROLE");

    address public immutable override TOKEN;
    address public immutable override WNATIVE;

    /* @custom:storage-location erc7201:ccip-csr.storage.CustomSender */
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

    /**
     * @dev Sets the immutable values for {TOKEN}, {WNATIVE}, {LINK_TOKEN}, and {CCIP_ROUTER} and the initial values for
     * the oracle pool and the admin role.
     */
    constructor(
        address token,
        address wnative,
        address linkToken,
        address ccipRouter,
        address oraclePool,
        address initialAdmin
    ) CCIPSenderUpgradeable(linkToken) CCIPBaseUpgradeable(ccipRouter) {
        if (token == address(0) || wnative == address(0)) revert CustomSenderInvalidParameters();

        TOKEN = token;
        WNATIVE = wnative;

        initialize(oraclePool, initialAdmin);
    }

    /**
     * @dev Initializes the values for the oracle pool and the admin role.
     * If this contract isn't used as the implementation for a proxy contract, this function will be called by the constructor.
     */
    function initialize(address oraclePool, address initialAdmin) public initializer {
        if (initialAdmin == address(0)) revert CustomSenderInvalidParameters();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _setOraclePool(oraclePool);
    }

    /**
     * @dev Returns the address of the oracle pool.
     */
    function getOraclePool() public view override returns (address) {
        return _getCustomSenderStorage().oraclePool;
    }

    /**
     * @dev Sets the address of the oracle pool.
     * It also approves the maximum amount of WNative to the oracle pool and revokes the approval from the previous oracle pool.
     *
     * Requirements:
     *
     * - `msg.sender` must have the `DEFAULT_ADMIN_ROLE`.
     *
     * Emits a {OraclePoolSet} event.
     */
    function setOraclePool(address oraclePool) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setOraclePool(oraclePool);
    }

    /**
     * @dev Allows users to stake (W)Native to receive a staked token that isn't native to this chain.
     * The user sends (W)Native to this contract, a CCIP message is then sent to the receiver contract on the main chain
     * to mint the native staked token and send it back to the user on this chain.
     * The user has to pay the gas fee for the CCIP message and for the way back.
     * It is very important that the `feeDtoO` is sufficient to cover the gas fee for the way back, or the tokens may
     * get stuck depending on the bridge used for the way back.
     *
     * Requirements:
     *
     * - The amount sent must be greater than 0.
     * - The token sent must be the wrapped native token or native token.
     *
     * Emits a {SlowStake} event.
     */
    function slowStake(
        uint64 destChainSelector,
        address token,
        uint256 amount,
        bytes calldata feeOtoD,
        bytes calldata feeDtoO
    ) external payable virtual returns (bytes32 messageId) {
        if (amount == 0) revert CustomSenderZeroAmount();
        if (token != TOKEN && (token != address(0) || TOKEN != WNATIVE)) {
            revert CustomSenderInvalidToken();
        }

        token = _pullFrom(token, msg.sender, amount);

        messageId = _ccipBuildAndSend(destChainSelector, msg.sender, token, amount, feeOtoD, feeDtoO);

        emit SlowStake(msg.sender, destChainSelector, messageId, token, amount);

        TokenHelper.refundExcessNative(msg.sender);
    }

    /**
     * @dev Allows users to swap (W)Native for the native staked token using an oracle pool.
     * The user sends (W)Native to this contract, the oracle pool swaps the (W)Native for the native staked token,
     * and sends the native staked token back to the user.
     *
     * Requirements:
     *
     * - The amount sent must be greater than 0.
     * - The token sent must be the wrapped native token or native token.
     *
     * Emits a {FastStake} event.
     */
    function fastStake(address token, uint256 amount, uint256 minAmountOut)
        external
        payable
        virtual
        returns (uint256 amountOut)
    {
        if (amount == 0) revert CustomSenderZeroAmount();
        if (token != TOKEN && (token != address(0) || TOKEN != WNATIVE)) {
            revert CustomSenderInvalidToken();
        }

        address oraclePool = _getCustomSenderStorage().oraclePool;
        if (oraclePool == address(0)) revert CustomSenderOraclePoolNotSet();

        _pullFrom(token, msg.sender, amount);

        IERC20(TOKEN).forceApprove(oraclePool, amount);

        amountOut = IOraclePool(oraclePool).swap(msg.sender, amount, minAmountOut);

        emit FastStake(msg.sender, token, amount, amountOut);

        TokenHelper.refundExcessNative(msg.sender);
    }

    /**
     * @dev Allows the operator to synchronize this chain by sending the native tokens to the receiver contract on the main chain,
     * mint the native staked token and send it back to the oracle pool on this chain.
     * The operator has to pay the gas fee for the CCIP message and for the way back.
     * It is very important that the `feeOtoD` is sufficient to cover the gas fee for the way back, or the tokens may
     * get stuck depending on the bridge used for the way back.
     *
     * Requirements:
     *
     * - `msg.sender` must have the `SYNC_ROLE`.
     *
     * Emits a {Sync} event.
     */
    function sync(uint64 destChainSelector, uint256 amount, bytes calldata feeOtoD, bytes calldata feeDtoO)
        external
        payable
        virtual
        onlyRole(SYNC_ROLE)
        returns (bytes32 messageId)
    {
        if (amount == 0) revert CustomSenderZeroAmount();

        address oraclePool = _getCustomSenderStorage().oraclePool;
        if (oraclePool == address(0)) revert CustomSenderOraclePoolNotSet();

        IOraclePool(oraclePool).pull(TOKEN, amount);

        messageId = _ccipBuildAndSend(destChainSelector, oraclePool, TOKEN, amount, feeOtoD, feeDtoO);

        emit Sync(msg.sender, destChainSelector, messageId, amount);

        TokenHelper.refundExcessNative(msg.sender);
    }

    /**
     * @dev Sets the address of the oracle pool.
     *
     * Emits a {OraclePoolSet} event.
     */
    function _setOraclePool(address oraclePool) internal virtual {
        CustomSenderStorage storage $ = _getCustomSenderStorage();

        $.oraclePool = oraclePool;

        emit OraclePoolSet(oraclePool);
    }

    /**
     * @dev Pulls `amount` of `token` from `user` and sends them to this contract.
     * If `token` is the wrapped native token, it wraps the native token.
     *
     * Requirements:
     *
     * - `amount` must be greater than 0.
     *
     * Returns the token pulled.
     */
    function _pullFrom(address token, address user, uint256 amount) internal virtual returns (address) {
        if (amount > 0) {
            if (token != address(0)) {
                IERC20(token).safeTransferFrom(user, address(this), amount);
            } else {
                token = WNATIVE;
                _wrapNative(amount);
            }
        }

        return token;
    }

    /**
     * @dev Wraps `amount` of native token.
     *
     * Requirements:
     *
     * - The contract must have enough native balance.
     */
    function _wrapNative(uint256 amount) internal virtual {
        uint256 nativeBalance = address(this).balance;
        if (amount > nativeBalance) revert CustomSenderInsufficientNativeBalance(amount, nativeBalance);

        IWNative(WNATIVE).deposit{value: amount}();
    }

    /**
     * @dev Builds and sends a CCIP message to the CCIP router.
     * If the destination to origin fee is 0 or if the staked token is the wrapped native token, the
     * message will contain exactly one (token, amount) pair.
     * Else, the message will contain two (token, amount) pairs, one for the staked token and one for the fee.
     * This function will calculate the exact fee required for the message and send it to the router.
     * The origin to destination fee can be paid in LINK or native token.
     * Returns the message id.
     *
     * Requirements:
     *
     * - `token` must be the wrapped native token or staked token.
     * - `feeOtoD` must be a valid CCIP fee encoded with `FeeCodec.encodeCCIP`.
     * - `feeDtoO` must be a valid fee encoded from a function in the `FeeCodec` library.
     */
    function _ccipBuildAndSend(
        uint64 destChainSelector,
        address recipient,
        address token,
        uint256 amount,
        bytes calldata feeOtoD,
        bytes calldata feeDtoO
    ) internal virtual returns (bytes32 messageId) {
        Client.EVMTokenAmount[] memory tokenAmounts;
        {
            (uint256 feeAmountDtoO, bool payInLinkDtoO) = FeeCodec.decodeFee(feeDtoO);

            address feeTokenDtoO = payInLinkDtoO ? LINK_TOKEN : address(0);
            feeTokenDtoO = _pullFrom(feeTokenDtoO, msg.sender, feeAmountDtoO);

            if (token == feeTokenDtoO || feeAmountDtoO == 0) {
                tokenAmounts = new Client.EVMTokenAmount[](1);

                tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount + feeAmountDtoO});
            } else {
                tokenAmounts = new Client.EVMTokenAmount[](2);

                tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});
                tokenAmounts[1] = Client.EVMTokenAmount({token: feeTokenDtoO, amount: feeAmountDtoO});
            }
        }

        (uint256 maxFeeOtoD, bool payInLinkOtoD, uint256 gasLimitOtoD) = FeeCodec.decodeCCIP(feeOtoD);
        if (gasLimitOtoD < MIN_PROCESS_MESSAGE_GAS) revert CustomSenderInsufficientGas();

        bytes memory packedData = FeeCodec.encodePackedData(recipient, amount, feeDtoO);

        messageId = _ccipSend(destChainSelector, tokenAmounts, payInLinkOtoD, maxFeeOtoD, gasLimitOtoD, packedData);
    }
}
