// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {CCIPBaseUpgradeable} from "./CCIPBaseUpgradeable.sol";

abstract contract CCIPSenderUpgradeable is CCIPBaseUpgradeable {
    using SafeERC20 for IERC20;

    error CCIPSenderUnsupportedChain(uint64 destChainSelector);
    error CCIPSenderZeroAmount();
    error CCIPSenderZeroAddress();
    error CCIPSenderExceedsMaxFee(uint256 fee, uint256 maxFee);

    event ReceiverSet(uint64 indexed destChainSelector, bytes receiver);

    address public immutable LINK_TOKEN;

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

    constructor(address linkToken) {
        LINK_TOKEN = linkToken;
    }

    function __CCIPSender_init() internal onlyInitializing {
        __CCIPSender_init_unchained();
    }

    function __CCIPSender_init_unchained() internal onlyInitializing {
        IERC20(LINK_TOKEN).forceApprove(CCIP_ROUTER, type(uint256).max);
    }

    function getReceiver(uint64 destChainSelector) public view virtual returns (bytes memory) {
        return _getCCIPSenderStorage().receivers[destChainSelector];
    }

    function setReceiver(uint64 destChainSelector, bytes memory receiver) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _setReceiver(destChainSelector, receiver);
    }

    function _setReceiver(uint64 destChainSelector, bytes memory receiver) internal virtual {
        CCIPSenderStorage storage $ = _getCCIPSenderStorage();

        $.receivers[destChainSelector] = receiver;

        emit ReceiverSet(destChainSelector, receiver);
    }

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
