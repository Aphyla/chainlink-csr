// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../../contracts/ccip/CCIPTrustedSenderUpgradeable.sol";
import "../../contracts/ccip/CCIPSenderUpgradeable.sol";
import "../Mocks/MockERC20.sol";
import "../Mocks/MockCCIPRouter.sol";

contract CCIPTrustedSenderUpgradeableTest is Test {
    MockCCIPTrustedSender public sender;
    MockCCIPRouter ccipRouter;
    MockERC20 public linkToken;

    uint128 public constant LINK_FEE = 1e18;
    uint128 public constant NATIVE_FEE = 0.01e18;

    function setUp() public {
        linkToken = new MockERC20("LINK", "LINK", 18);
        ccipRouter = new MockCCIPRouter(address(linkToken), LINK_FEE, NATIVE_FEE);

        sender = new MockCCIPTrustedSender(address(linkToken), address(ccipRouter));

        vm.label(address(ccipRouter), "ccipRouter");
        vm.label(address(linkToken), "linkToken");
        vm.label(address(sender), "sender");
    }

    function test_Constructor() public {
        sender = new MockCCIPTrustedSender(address(linkToken), address(ccipRouter)); // to fix coverage

        assertEq(sender.CCIP_ROUTER(), address(ccipRouter), "test_Constructor::1");
        assertEq(sender.LINK_TOKEN(), address(linkToken), "test_Constructor::2");
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

    mapping(bytes32 salt => address) public tokens;

    function test_Fuzz_CCIPSend(
        bytes memory receiver,
        uint64 destChainSelector,
        bytes32[] memory tokenSalts,
        uint128[] memory amounts,
        bool payInLink,
        uint32 gasLimit,
        bytes memory data
    ) public {
        vm.assume(receiver.length > 0 && tokenSalts.length > 0 && amounts.length > 0);

        uint256 length = tokenSalts.length > 10 ? 10 : tokenSalts.length;
        length = amounts.length > length ? length : amounts.length;

        sender.setReceiver(destChainSelector, receiver);

        uint256 nativeFee;
        if (payInLink) {
            nativeFee = 0;

            linkToken.mint(address(this), LINK_FEE);
            linkToken.approve(address(sender), LINK_FEE);
        } else {
            nativeFee = NATIVE_FEE;
        }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 salt = tokenSalts[i];

            address token = tokens[salt];
            uint256 amount = bound(amounts[i], 1, type(uint128).max);

            if (token == address(0)) {
                token = address(new MockERC20{salt: salt}("TOKEN", "TOKEN", 18));
                tokens[salt] = token;
            }

            MockERC20(token).mint(address(sender), amount);

            tokenAmounts[i] = Client.EVMTokenAmount({token: token, amount: amount});
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: data,
            tokenAmounts: tokenAmounts,
            feeToken: payInLink ? address(linkToken) : address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit}))
        });

        bytes32 messageId =
            sender.ccipSend{value: nativeFee}(destChainSelector, tokenAmounts, payInLink, LINK_FEE, gasLimit, data);

        assertEq(messageId, keccak256("test"), "test_Fuzz_CCIPSend::1");
        assertEq(ccipRouter.value(), payInLink ? 0 : NATIVE_FEE, "test_Fuzz_CCIPSend::2");
        assertEq(linkToken.balanceOf(address(ccipRouter)), payInLink ? LINK_FEE : 0, "test_Fuzz_CCIPSend::3");
        assertEq(ccipRouter.data(), abi.encode(destChainSelector, message), "test_Fuzz_CCIPSend::4");
    }

    function test_Fuzz_Revert_CCIPSend(bytes memory receiver, uint64 destChainSelector, bool payInLink, uint256 maxFee)
        public
    {
        vm.assume(receiver.length > 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPTrustedSenderUpgradeable.CCIPTrustedSenderUnsupportedChain.selector, destChainSelector
            )
        );
        sender.ccipSend(destChainSelector, new Client.EVMTokenAmount[](1), false, 0, 0, new bytes(0));

        sender.setReceiver(destChainSelector, receiver);

        uint256 fee = payInLink ? LINK_FEE : NATIVE_FEE;
        uint256 invalidFee = bound(maxFee, 0, fee - 1);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(linkToken), amount: 1});

        vm.expectRevert(
            abi.encodeWithSelector(ICCIPSenderUpgradeable.CCIPSenderExceedsMaxFee.selector, fee, invalidFee)
        );
        sender.ccipSend(destChainSelector, tokenAmounts, payInLink, invalidFee, 0, new bytes(0));
    }

    function test_Fuzz_Initialize() public {
        sender = new MockCCIPTrustedSender(address(linkToken), address(ccipRouter));

        sender.initialize();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sender.initialize();
    }

    function test_Fuzz_InitializeUnchained() public {
        sender = new MockCCIPTrustedSender(address(linkToken), address(ccipRouter));

        sender.initializeUnchained();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sender.initializeUnchained();
    }

    function test_Fuzz_BadInitialize() public {
        sender = new MockCCIPTrustedSender(address(linkToken), address(ccipRouter));

        vm.expectRevert(Initializable.NotInitializing.selector);
        sender.badInitialize();
    }
}

contract MockCCIPTrustedSender is CCIPTrustedSenderUpgradeable {
    constructor(address linkToken, address ccipRouter)
        CCIPSenderUpgradeable(linkToken)
        CCIPBaseUpgradeable(ccipRouter)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initialize() public initializer {
        __CCIPTrustedSender_init();
    }

    function initializeUnchained() public initializer {
        __CCIPTrustedSender_init_unchained();
    }

    function badInitialize() public {
        __CCIPTrustedSender_init();
    }

    function ccipSend(
        uint64 destChainSelector,
        Client.EVMTokenAmount[] memory tokenAmounts,
        bool payInLink,
        uint256 maxFee,
        uint32 gasLimit,
        bytes calldata data
    ) external payable returns (bytes32) {
        return _ccipSend(destChainSelector, tokenAmounts, payInLink, maxFee, gasLimit, data);
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
