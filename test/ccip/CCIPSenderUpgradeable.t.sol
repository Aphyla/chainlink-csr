// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../../contracts/ccip/CCIPSenderUpgradeable.sol";
import "../../contracts/ccip/CCIPSenderUpgradeable.sol";
import "../Mocks/MockERC20.sol";
import "../Mocks/MockCCIPRouter.sol";

contract CCIPSenderUpgradeableTest is Test {
    MockCCIPSender public sender;
    MockCCIPRouter ccipRouter;
    MockERC20 public linkToken;

    uint128 public constant LINK_FEE = 1e18;
    uint128 public constant NATIVE_FEE = 0.01e18;

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
    }

    mapping(address => uint256) public _sent;

    function test_Fuzz_CCIPSend(
        uint64 destChainSelector,
        bytes memory receiver,
        Client.EVMTokenAmount[] memory tokenAmounts,
        bool payInLink,
        uint256 maxFee,
        uint32 gasLimit,
        bytes memory data
    ) public {
        vm.assume(receiver.length > 0);

        uint256 fee;
        if (payInLink) {
            fee = LINK_FEE;

            linkToken.mint(address(this), fee);
            linkToken.approve(address(sender), fee);
        } else {
            fee = NATIVE_FEE;
        }

        maxFee = bound(maxFee, fee, 100e18);

        bytes memory tokenCode = address(linkToken).code;
        for (uint256 i = 0; i < tokenAmounts.length; i++) {
            address token = tokenAmounts[i].token;
            uint256 amount = tokenAmounts[i].amount;

            token = address(uint160(uint256(keccak256(abi.encode(uint256(keccak256(abi.encode(token))) - 1))))); // Should prevent any collisions

            vm.etch(address(token), tokenCode);

            amount = bound(amount, 1, type(uint256).max - _sent[token] - tokenAmounts.length);

            tokenAmounts[i] = Client.EVMTokenAmount({token: token, amount: amount});
            _sent[token] += amount;

            MockERC20(token).mint(address(sender), amount);
        }

        bytes32 messageId = sender.ccipSendTo{value: payInLink ? 0 : fee}(
            destChainSelector, receiver, tokenAmounts, payInLink, maxFee, gasLimit, data
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: data,
            tokenAmounts: tokenAmounts,
            feeToken: payInLink ? address(linkToken) : address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit}))
        });

        assertEq(messageId, keccak256("test"), "test_Fuzz_CCIPSend::1");
        assertEq(ccipRouter.value(), payInLink ? 0 : fee, "test_Fuzz_CCIPSend::2");
        assertEq(ccipRouter.data(), abi.encode(destChainSelector, message), "test_Fuzz_CCIPSend::3");

        for (uint256 i = 0; i < tokenAmounts.length; i++) {
            address token = tokenAmounts[i].token;

            assertEq(MockERC20(token).balanceOf(address(ccipRouter)), _sent[token], "test_Fuzz_CCIPSend::4");
            assertEq(MockERC20(token).balanceOf(address(this)), 0, "test_Fuzz_CCIPSend::5");
            assertEq(MockERC20(token).balanceOf(address(sender)), 0, "test_Fuzz_CCIPSend::6");
        }
    }

    function test_Revert_CCIPSend() public {
        vm.expectRevert(ICCIPSenderUpgradeable.CCIPSenderEmptyReceiver.selector);
        sender.ccipSendTo(0, new bytes(0), new Client.EVMTokenAmount[](0), false, 0, 0, new bytes(0));
    }

    function test_Fuzz_Revert_CCIPSend(bool payInLink, uint256 fee) public {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

        vm.expectRevert(ICCIPSenderUpgradeable.CCIPSenderInvalidTokenAmount.selector);
        sender.ccipSendTo(0, new bytes(1), tokenAmounts, payInLink, 0, 0, new bytes(0));

        tokenAmounts[0] = Client.EVMTokenAmount({token: address(linkToken), amount: 0});

        vm.expectRevert(ICCIPSenderUpgradeable.CCIPSenderInvalidTokenAmount.selector);
        sender.ccipSendTo(0, new bytes(1), tokenAmounts, payInLink, 0, 0, new bytes(0));

        tokenAmounts[0] = Client.EVMTokenAmount({token: address(0), amount: 1});

        vm.expectRevert(ICCIPSenderUpgradeable.CCIPSenderInvalidTokenAmount.selector);
        sender.ccipSendTo(0, new bytes(1), tokenAmounts, payInLink, 0, 0, new bytes(0));

        fee = bound(fee, 0, (payInLink ? LINK_FEE : NATIVE_FEE) - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPSenderUpgradeable.CCIPSenderExceedsMaxFee.selector, payInLink ? LINK_FEE : NATIVE_FEE, fee
            )
        );
        sender.ccipSendTo(0, new bytes(1), new Client.EVMTokenAmount[](0), payInLink, fee, 0, new bytes(0));
    }

    function test_Fuzz_Initialize() public {
        sender = new MockCCIPSender(address(linkToken), address(ccipRouter));

        sender.initialize();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sender.initialize();
    }

    function test_Fuzz_InitializeUnchained() public {
        sender = new MockCCIPSender(address(linkToken), address(ccipRouter));

        sender.initializeUnchained();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sender.initializeUnchained();
    }

    function test_Fuzz_BadInitialize() public {
        sender = new MockCCIPSender(address(linkToken), address(ccipRouter));

        vm.expectRevert(Initializable.NotInitializing.selector);
        sender.badInitialize();
    }
}

contract MockCCIPSender is CCIPSenderUpgradeable {
    constructor(address linkToken, address ccipRouter)
        CCIPSenderUpgradeable(linkToken)
        CCIPBaseUpgradeable(ccipRouter)
    {}

    function initialize() public initializer {
        __CCIPSender_init();
    }

    function initializeUnchained() public initializer {
        __CCIPSender_init_unchained();
    }

    function badInitialize() public {
        __CCIPSender_init();
    }

    function ccipSendTo(
        uint64 destChainSelector,
        bytes memory receiver,
        Client.EVMTokenAmount[] memory tokenAmounts,
        bool payInLink,
        uint256 maxFee,
        uint32 gasLimit,
        bytes memory data
    ) external payable returns (bytes32) {
        return _ccipSendTo(destChainSelector, msg.sender, receiver, tokenAmounts, payInLink, maxFee, gasLimit, data);
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
