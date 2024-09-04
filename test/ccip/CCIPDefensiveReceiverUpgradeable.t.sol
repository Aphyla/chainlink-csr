// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../../contracts/ccip/CCIPDefensiveReceiverUpgradeable.sol";

import "../mocks/MockERC20.sol";

contract CCIPDefensiveReceiverUpgradeableTest is Test {
    MockCCIPReceiver receiver;
    MockERC20 mockToken;

    address ccipRouter = makeAddr("ccipRouter");

    function setUp() public {
        receiver = new MockCCIPReceiver(ccipRouter);
        mockToken = new MockERC20("Token", "TKN", 18);
    }

    function test_Constructor() public view {
        assertEq(receiver.CCIP_ROUTER(), ccipRouter, "test_Constructor::1");
    }

    function test_Initialize() public {
        receiver.initialize();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        receiver.initializeUnchained();
    }

    function test_InitializeUnchained() public {
        receiver.initializeUnchained();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        receiver.initialize();
    }

    function test_Fuzz_SetSender(
        uint64 destChainSelector1,
        uint64 destChainSelector2,
        bytes memory sender1,
        bytes memory sender2
    ) public {
        vm.assume(keccak256(sender1) != keccak256(sender2) && destChainSelector1 != destChainSelector2);

        assertEq(keccak256(receiver.getSender(destChainSelector1)), keccak256(new bytes(0)), "test_Fuzz_SetSender::1");
        assertEq(keccak256(receiver.getSender(destChainSelector2)), keccak256(new bytes(0)), "test_Fuzz_SetSender::2");

        receiver.setSender(destChainSelector1, sender1);

        assertEq(keccak256(receiver.getSender(destChainSelector1)), keccak256(sender1), "test_Fuzz_SetSender::3");
        assertEq(keccak256(receiver.getSender(destChainSelector2)), keccak256(new bytes(0)), "test_Fuzz_SetSender::4");

        receiver.setSender(destChainSelector2, sender2);

        assertEq(keccak256(receiver.getSender(destChainSelector1)), keccak256(sender1), "test_Fuzz_SetSender::5");
        assertEq(keccak256(receiver.getSender(destChainSelector2)), keccak256(sender2), "test_Fuzz_SetSender::6");

        receiver.setSender(destChainSelector1, new bytes(0));

        assertEq(keccak256(receiver.getSender(destChainSelector1)), keccak256(new bytes(0)), "test_Fuzz_SetSender::7");
        assertEq(keccak256(receiver.getSender(destChainSelector2)), keccak256(sender2), "test_Fuzz_SetSender::8");

        receiver.setSender(destChainSelector2, new bytes(0));

        assertEq(keccak256(receiver.getSender(destChainSelector1)), keccak256(new bytes(0)), "test_Fuzz_SetSender::9");
        assertEq(keccak256(receiver.getSender(destChainSelector2)), keccak256(new bytes(0)), "test_Fuzz_SetSender::10");

        receiver.setSender(destChainSelector1, sender2);
        receiver.setSender(destChainSelector2, sender1);

        assertEq(keccak256(receiver.getSender(destChainSelector1)), keccak256(sender2), "test_Fuzz_SetSender::11");
        assertEq(keccak256(receiver.getSender(destChainSelector2)), keccak256(sender1), "test_Fuzz_SetSender::12");
    }

    function test_Fuzz_Revert_SetSender(address msgSender) public {
        vm.assume(msgSender != address(this));

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, msgSender, 0));
        vm.prank(msgSender);
        receiver.setSender(0, abi.encode(keccak256(new bytes(0))));
    }

    function test_Fuzz_CCIPReceiveSuccess(
        uint64 destChainSelector,
        bytes32 messageId,
        bytes memory sender,
        bytes memory data,
        address token,
        uint256 amount
    ) public {
        vm.assume(sender.length > 0);

        receiver.setSender(destChainSelector, sender);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: destChainSelector,
            sender: sender,
            data: data,
            destTokenAmounts: tokenAmounts
        });

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(keccak256(receiver.data()), keccak256(abi.encode(message)), "test_Fuzz_CCIPReceiveSuccess::1");
    }

    function test_Fuzz_Revert_CCIPReceive(
        address msgSender,
        uint64 destChainSelector,
        bytes32 messageId,
        bytes memory sender1,
        bytes memory sender2,
        bytes memory data
    ) public {
        vm.assume(
            msgSender != ccipRouter && sender1.length > 0 && sender2.length > 0
                && keccak256(sender1) != keccak256(sender2)
        );

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: destChainSelector,
            sender: sender1,
            data: data,
            destTokenAmounts: new Client.EVMTokenAmount[](1)
        });

        vm.expectRevert(ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverOnlyCCIPRouter.selector);
        vm.prank(msgSender);
        receiver.ccipReceive(message);

        vm.prank(ccipRouter);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverUnsupportedChain.selector, destChainSelector
            )
        );
        receiver.ccipReceive(message);

        receiver.setSender(destChainSelector, sender2);

        vm.prank(ccipRouter);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverUnauthorizedSender.selector, sender1, sender2
            )
        );
        receiver.ccipReceive(message);
    }

    function test_Fuzz_RetryFailedMessage(
        uint64 destChainSelector,
        bytes32 messageId,
        bytes memory sender,
        bytes memory data,
        address token,
        uint256 amount
    ) public {
        vm.assume(sender.length > 0);

        receiver.setSender(destChainSelector, sender);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: destChainSelector,
            sender: sender,
            data: data,
            destTokenAmounts: tokenAmounts
        });

        receiver.setPaused(true);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(receiver.data().length, 0, "test_Fuzz_RetryFailedMessage::1");

        bytes32 hash = keccak256(abi.encode(message));

        assertEq(receiver.getFailedMessageHash(messageId), hash, "test_Fuzz_RetryFailedMessage::2");

        receiver.setPaused(false);

        receiver.retryFailedMessage(message);

        assertEq(keccak256(receiver.data()), keccak256(abi.encode(message)), "test_Fuzz_RetryFailedMessage::3");
    }

    function test_Fuzz_Revert_RetryFailedMessage(
        uint64 destChainSelector,
        bytes32 messageId,
        bytes memory sender,
        bytes memory data,
        address token,
        uint256 amount
    ) public {
        vm.assume(keccak256(sender) != keccak256(abi.encode(address(this))) && sender.length > 0);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: destChainSelector,
            sender: sender,
            data: data,
            destTokenAmounts: tokenAmounts
        });

        receiver.setSender(destChainSelector, sender);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverMessageNotFound.selector, message.messageId
            )
        );
        receiver.retryFailedMessage(message);

        receiver.setPaused(true);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        vm.expectRevert("Paused");
        receiver.retryFailedMessage(message);

        bytes32 expectedHash = keccak256(abi.encode(message));

        message.sender = abi.encode(address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverMismatchedMessage.selector,
                message.messageId,
                keccak256(abi.encode(message)),
                expectedHash
            )
        );
        receiver.retryFailedMessage(message);

        message.sender = sender;

        receiver.setPaused(false);

        receiver.retryFailedMessage(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_Fuzz_Revert_RetryFailedMessage::1");
        assertEq(keccak256(receiver.data()), expectedHash, "test_Fuzz_Revert_RetryFailedMessage::2");

        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverMessageNotFound.selector, message.messageId
            )
        );
        receiver.retryFailedMessage(message);
    }

    function test_Fuzz_RecoverFailedMessage(
        uint64 destChainSelector,
        bytes32 messageId,
        bytes memory sender,
        bytes memory data,
        uint256 amount
    ) public {
        vm.assume(sender.length > 0);

        receiver.setSender(destChainSelector, sender);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(mockToken), amount: amount});

        mockToken.mint(address(receiver), amount);

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: destChainSelector,
            sender: sender,
            data: data,
            destTokenAmounts: tokenAmounts
        });

        receiver.setPaused(true);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(receiver.data().length, 0, "test_Fuzz_RecoverFailedMessage::1");

        bytes32 hash = keccak256(abi.encode(message));

        assertEq(receiver.getFailedMessageHash(messageId), hash, "test_Fuzz_RecoverFailedMessage::2");

        vm.expectRevert("Paused");
        receiver.retryFailedMessage(message);

        receiver.recoverTokens(message, address(this));
    }

    function test_Revert_RecoverFailedMessage() public {
        Client.Any2EVMMessage memory message;
        vm.expectRevert(ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverZeroAddress.selector);
        receiver.recoverTokens(message, address(0));
    }

    function test_Fuzz_Revert_RecoverFailedMessage(
        address msgSender,
        uint64 destChainSelector,
        bytes32 messageId,
        bytes memory sender,
        bytes memory data,
        uint256 amount
    ) public {
        vm.assume(msgSender != address(this));
        vm.assume(sender.length > 0);

        receiver.setSender(destChainSelector, sender);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(mockToken), amount: amount});

        mockToken.mint(address(receiver), amount);

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: destChainSelector,
            sender: sender,
            data: data,
            destTokenAmounts: tokenAmounts
        });

        receiver.setPaused(true);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        vm.prank(msgSender);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, msgSender, 0));
        receiver.recoverTokens(message, address(this));
    }

    function test_Fuzz_Revert_ProcessMessage(address sender) public {
        vm.assume(sender != address(receiver));

        Client.Any2EVMMessage memory message;

        vm.expectRevert(ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverOnlySelf.selector);
        vm.prank(sender);
        receiver.processMessage(message);
    }

    function test_Fuzz_SupportsInterface(bytes4 interfaceId) public view {
        vm.assume(
            interfaceId != type(IAny2EVMMessageReceiver).interfaceId && interfaceId != type(IAccessControl).interfaceId
                && interfaceId != type(IERC165).interfaceId
        );

        assertEq(
            receiver.supportsInterface(type(IAny2EVMMessageReceiver).interfaceId),
            true,
            "test_Fuzz_SupportsInterface::1"
        );
        assertEq(receiver.supportsInterface(type(IAccessControl).interfaceId), true, "test_Fuzz_SupportsInterface::2");
        assertEq(receiver.supportsInterface(type(IERC165).interfaceId), true, "test_Fuzz_SupportsInterface::3");

        assertEq(receiver.supportsInterface(interfaceId), false, "test_Fuzz_SupportsInterface::4");
    }
}

contract MockCCIPReceiver is CCIPDefensiveReceiverUpgradeable {
    bytes public data;
    bool public paused;

    constructor(address ccipRouter) CCIPBaseUpgradeable(ccipRouter) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initializeUnchained() public initializer {
        __CCIPDefensiveReceiver_init_unchained();
    }

    function initialize() public initializer {
        __CCIPDefensiveReceiver_init();
    }

    function setPaused(bool _paused) public {
        paused = _paused;
    }

    function _processMessage(Client.Any2EVMMessage calldata message) internal override {
        if (paused) revert("Paused");

        data = abi.encode(message);
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
