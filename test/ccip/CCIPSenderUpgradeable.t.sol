// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../../contracts/ccip/CCIPSenderUpgradeable.sol";
import "../Mocks/MockERC20.sol";

contract CCIPSenderUpgradeableTest is Test {
    MockCCIPSender public sender;
    MockCCIPRouter ccipRouter;
    MockERC20 public linkToken;

    uint256 public constant LINK_FEE = 1e18;
    uint256 public constant NATIVE_FEE = 0.01e18;

    function setUp() public {
        linkToken = new MockERC20("LINK", "LINK", 18);
        ccipRouter = new MockCCIPRouter(address(linkToken), LINK_FEE, NATIVE_FEE);

        sender = new MockCCIPSender(address(linkToken), address(ccipRouter));

        vm.label(address(ccipRouter), "ccipRouter");
        vm.label(address(linkToken), "linkToken");
        vm.label(address(sender), "sender");
    }

    function test_Constructor() public {
        sender = new MockCCIPSender(address(linkToken), address(ccipRouter)); // to fix coverage

        assertEq(sender.CCIP_ROUTER(), address(ccipRouter), "test_Constructor::1");
        assertEq(sender.LINK_TOKEN(), address(linkToken), "test_Constructor::2");
        assertEq(linkToken.allowance(address(sender), address(ccipRouter)), type(uint256).max, "test_Constructor::3");
    }

    function test_SetReceiver(
        uint64 destChainSelector1,
        uint64 destChainSelector2,
        bytes memory receiver1,
        bytes memory receiver2
    ) public {
        vm.assume(keccak256(receiver1) != keccak256(receiver2) && destChainSelector1 != destChainSelector2);

        assertEq(keccak256(sender.getReceiver(destChainSelector1)), keccak256(new bytes(0)), "test_SetReceiver::1");
        assertEq(keccak256(sender.getReceiver(destChainSelector2)), keccak256(new bytes(0)), "test_SetReceiver::2");

        sender.setReceiver(destChainSelector1, receiver1);

        assertEq(keccak256(sender.getReceiver(destChainSelector1)), keccak256(receiver1), "test_SetReceiver::3");
        assertEq(keccak256(sender.getReceiver(destChainSelector2)), keccak256(new bytes(0)), "test_SetReceiver::4");

        sender.setReceiver(destChainSelector2, receiver2);

        assertEq(keccak256(sender.getReceiver(destChainSelector1)), keccak256(receiver1), "test_SetReceiver::5");
        assertEq(keccak256(sender.getReceiver(destChainSelector2)), keccak256(receiver2), "test_SetReceiver::6");

        sender.setReceiver(destChainSelector1, new bytes(0));

        assertEq(keccak256(sender.getReceiver(destChainSelector1)), keccak256(new bytes(0)), "test_SetReceiver::7");
        assertEq(keccak256(sender.getReceiver(destChainSelector2)), keccak256(receiver2), "test_SetReceiver::8");

        sender.setReceiver(destChainSelector2, new bytes(0));

        assertEq(keccak256(sender.getReceiver(destChainSelector1)), keccak256(new bytes(0)), "test_SetReceiver::9");
        assertEq(keccak256(sender.getReceiver(destChainSelector2)), keccak256(new bytes(0)), "test_SetReceiver::10");

        sender.setReceiver(destChainSelector1, receiver2);
        sender.setReceiver(destChainSelector2, receiver1);

        assertEq(keccak256(sender.getReceiver(destChainSelector1)), keccak256(receiver2), "test_SetReceiver::11");
        assertEq(keccak256(sender.getReceiver(destChainSelector2)), keccak256(receiver1), "test_SetReceiver::12");
    }

    function test_Fuzz_Revert_SetSender(address msgSender) public {
        vm.assume(msgSender != address(this));

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, msgSender, 0));
        vm.prank(msgSender);
        sender.setReceiver(0, abi.encode(keccak256(new bytes(0))));
    }

    function test_Fuzz_CCIPSend(
        bytes memory receiver,
        uint64 destChainSelector,
        address token,
        uint256 amount,
        bool payInLink,
        uint256 gasLimit,
        bytes memory data
    ) public {
        vm.assume(receiver.length > 0 && amount > 0);

        sender.setReceiver(destChainSelector, receiver);

        uint256 nativeFee;
        if (payInLink) {
            nativeFee = 0;

            linkToken.mint(address(this), LINK_FEE);
            linkToken.approve(address(sender), LINK_FEE);
        } else {
            nativeFee = NATIVE_FEE;
        }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: data,
            tokenAmounts: tokenAmounts,
            feeToken: payInLink ? address(linkToken) : address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit}))
        });

        bytes32 messageId =
            sender.ccipSend{value: nativeFee}(destChainSelector, token, amount, payInLink, LINK_FEE, gasLimit, data);

        assertEq(messageId, keccak256("test"), "test_Fuzz_CCIPSend::1");
        assertEq(ccipRouter.value(), payInLink ? 0 : NATIVE_FEE, "test_Fuzz_CCIPSend::2");
        assertEq(linkToken.balanceOf(address(ccipRouter)), payInLink ? LINK_FEE : 0, "test_Fuzz_CCIPSend::3");
        assertEq(ccipRouter.data(), abi.encode(destChainSelector, message), "test_Fuzz_CCIPSend::4");
    }

    function test_Revert_CCIPSend() public {
        vm.expectRevert(CCIPSenderUpgradeable.CCIPSenderZeroAmount.selector);
        sender.ccipSend(0, address(0), 0, false, 0, 0, new bytes(0));
    }

    function test_Fuzz_Revert_CCIPSend(bytes memory receiver, uint64 destChainSelector, bool payInLink, uint256 maxFee)
        public
    {
        vm.assume(receiver.length > 0);

        vm.expectRevert(
            abi.encodeWithSelector(CCIPSenderUpgradeable.CCIPSenderUnsupportedChain.selector, destChainSelector)
        );
        sender.ccipSend(destChainSelector, address(0), 1, false, 0, 0, new bytes(0));

        sender.setReceiver(destChainSelector, receiver);

        uint256 fee = payInLink ? LINK_FEE : NATIVE_FEE;
        uint256 invalidFee = bound(maxFee, 0, fee - 1);

        vm.expectRevert(abi.encodeWithSelector(CCIPSenderUpgradeable.CCIPSenderExceedsMaxFee.selector, fee, invalidFee));
        sender.ccipSend(destChainSelector, address(0), 1, payInLink, invalidFee, 0, new bytes(0));
    }
}

contract MockCCIPSender is CCIPSenderUpgradeable {
    constructor(address linkToken, address ccipRouter)
        CCIPSenderUpgradeable(linkToken)
        CCIPBaseUpgradeable(ccipRouter)
    {
        initialize();
    }

    function initialize() public initializer {
        __CCIPSender_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function ccipSend(
        uint64 destChainSelector,
        address token,
        uint256 amount,
        bool payInLink,
        uint256 maxFee,
        uint256 gasLimit,
        bytes calldata data
    ) external payable returns (bytes32) {
        return _ccipSend(destChainSelector, token, amount, payInLink, maxFee, gasLimit, data);
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}

contract MockCCIPRouter {
    IERC20 public immutable LINK_TOKEN;

    bytes public data;
    uint256 public value;
    uint256 private _linkFee;
    uint256 private _nativeFee;

    constructor(address linkToken, uint256 linkFee, uint256 nativeFee) {
        LINK_TOKEN = IERC20(linkToken);
        _linkFee = linkFee;
        _nativeFee = nativeFee;
    }

    function getFee(uint64, Client.EVM2AnyMessage calldata message) public view returns (uint256) {
        return message.feeToken == address(LINK_TOKEN) ? _linkFee : _nativeFee;
    }

    function ccipSend(uint64 destChainSelector, Client.EVM2AnyMessage calldata message)
        external
        payable
        returns (bytes32)
    {
        uint256 fee = getFee(destChainSelector, message);

        if (message.feeToken == address(LINK_TOKEN)) {
            LINK_TOKEN.transferFrom(msg.sender, address(this), fee);
        } else {
            require(msg.value == fee, "CCIPRouter: insufficient fee");
        }

        value = msg.value;
        data = abi.encode(destChainSelector, message);

        return keccak256("test");
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
