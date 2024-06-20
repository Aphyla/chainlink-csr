// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {CCIPBaseUpgradeable} from "./CCIPBaseUpgradeable.sol";
import {ICCIPSenderUpgradeable} from "../interfaces/ICCIPSenderUpgradeable.sol";

/**
 * @title CCIPSenderUpgradeable Contract
 * @dev The base contract for all CCIP sender contracts.
 * It provides the ability to send messages to the CCIP router using the `ccipSend` function.
 * Each message can contain exactly one (token, amount) pair.
 */
abstract contract CCIPSenderUpgradeable is CCIPBaseUpgradeable, ICCIPSenderUpgradeable {
    using SafeERC20 for IERC20;

    address public immutable override LINK_TOKEN;

    /* @custom:storage-location erc72101:ccip-csr.storage.CCIPSender */
    struct CCIPSenderStorage {
        mapping(uint64 destChainSelector => bytes receiver) receivers;
    }

    // keccak256(abi.encode(uint256(keccak256("ccip-csr.storage.CCIPSender")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CCIPSenderStorageLocation =
        0xf66fb1c3b00f628025d034a8810c0eebf8fe092bac84fc6ed49207861b4b6d00;

    function _getCCIPSenderStorage() private pure returns (CCIPSenderStorage storage $) {
        assembly {
            $.slot := CCIPSenderStorageLocation
        }
    }

    /**
     * @dev Sets the immutable value for {LINK_TOKEN}.
     */
    constructor(address linkToken) {
        LINK_TOKEN = linkToken;
    }

    /**
     * @dev Initializes the contract.
     */
    function __CCIPSender_init() internal onlyInitializing {
        __CCIPSender_init_unchained();
    }

    /**
     * @dev Initializes the contract by approving the maximum amount of LINK tokens to the CCIP router.
     */
    function __CCIPSender_init_unchained() internal onlyInitializing {
        IERC20(LINK_TOKEN).forceApprove(CCIP_ROUTER, type(uint256).max);
    }

    /**
     * @dev Returns the receiver for the destination chain selector.
     */
    function getReceiver(uint64 destChainSelector) public view virtual override returns (bytes memory) {
        return _getCCIPSenderStorage().receivers[destChainSelector];
    }

    /**
     * @dev Sets the receiver for the destination chain selector.
     * If the destination chain is an EVM chain, the receiver should be encoded using `abi.encode(address)`.
     *
     * Requirements:
     *
     * - `msg.sender` must have the `DEFAULT_ADMIN_ROLE`.
     *
     * Emits a {ReceiverSet} event.
     */
    function setReceiver(uint64 destChainSelector, bytes memory receiver)
        public
        virtual
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setReceiver(destChainSelector, receiver);
    }

    /**
     * @dev Sets the receiver for the destination chain selector.
     * If the destination chain is an EVM chain, the receiver should be encoded using `abi.encode(address)`.
     *
     * Emits a {ReceiverSet} event.
     */
    function _setReceiver(uint64 destChainSelector, bytes memory receiver) internal virtual {
        CCIPSenderStorage storage $ = _getCCIPSenderStorage();

        $.receivers[destChainSelector] = receiver;

        emit ReceiverSet(destChainSelector, receiver);
    }

    /**
     * @dev Sends a message to the CCIP router.
     * The message will contain exactly one (token, amount) pair.
     * This function will calculate the exact fee required for the message and send it to the router.
     * The fee can be paid in LINK or native token.
     *
     * Requirements:
     *
     * - `amount` must be greater than 0.
     * - `destChainSelector` must be a supported chain.
     * - `maxFee` must be greater than or equal to the fee for the message.
     * - if `payInLink` is `true`, `msg.sender` must have approved the contract to transfer `maxFee` of LINK. Else,
     *   `msg.value` must be greater than or equal to the fee for the message.
     * - `msg.sender` must have approved the contract to transfer `amount` of `token`.
     */
    function _ccipSend(
        uint64 destChainSelector,
        address token,
        uint256 amount,
        bool payInLink,
        uint256 maxFee,
        uint256 gasLimit,
        bytes memory data
    ) internal virtual returns (bytes32) {
        if (amount == 0) revert CCIPSenderZeroAmount();

        bytes memory receiver = getReceiver(destChainSelector);
        if (receiver.length == 0) revert CCIPSenderUnsupportedChain(destChainSelector);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: data,
            tokenAmounts: tokenAmounts,
            feeToken: payInLink ? LINK_TOKEN : address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit}))
        });

        uint256 fee = IRouterClient(CCIP_ROUTER).getFee(destChainSelector, message);
        if (fee > maxFee) revert CCIPSenderExceedsMaxFee(fee, maxFee);

        uint256 nativeFee;
        if (payInLink) {
            nativeFee = 0;
            IERC20(LINK_TOKEN).safeTransferFrom(msg.sender, address(this), fee);
        } else {
            nativeFee = fee;
        }

        return IRouterClient(CCIP_ROUTER).ccipSend{value: nativeFee}(destChainSelector, message);
    }
}
