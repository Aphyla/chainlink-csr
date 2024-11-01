// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockWNative.sol";

import "../../contracts/receivers/CustomReceiver.sol";
import "../../contracts/ccip/CCIPBaseUpgradeable.sol";
import "../../contracts/interfaces/ICCIPDefensiveReceiverUpgradeable.sol";

contract CustomReceiverTest is Test {
    MockReceiver receiver;
    MockVault vault;
    MockERC20 link;
    MockWNative wnative;
    MockAdapter adapter;

    address ccipRouter = makeAddr("CCIP Router");
    address l2Sender = makeAddr("L2 Sender");

    function setUp() public {
        adapter = new MockAdapter();
        link = new MockERC20("Link", "LINK", 18);
        wnative = new MockWNative();
        vault = new MockVault(address(wnative));
        receiver = new MockReceiver(address(vault), address(wnative), address(ccipRouter), address(this));

        vault.depositNative{value: 1e18}(address(1));

        wnative.deposit{value: 1e18}();
        wnative.transfer(address(vault), 1e18);

        assertEq(vault.previewDeposit(1e18), 0.5e18, "setUp::1");
    }

    function test_Constructor() public {
        receiver = new MockReceiver(address(vault), address(wnative), address(ccipRouter), address(this)); // to fix coverage

        assertEq(receiver.VAULT_TOKEN(), address(vault), "test_Constructor::1");
        assertEq(receiver.WNATIVE(), address(wnative), "test_Constructor::2");
        assertEq(receiver.CCIP_ROUTER(), address(ccipRouter), "test_Constructor::3");
        assertEq(receiver.hasRole(receiver.DEFAULT_ADMIN_ROLE(), address(this)), true, "test_Constructor::4");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(ICustomReceiver.CustomReceiverInvalidParameters.selector);
        receiver = new MockReceiver(address(vault), address(0), address(ccipRouter), address(this));

        vm.expectRevert(ICCIPBaseUpgradeable.CCIPBaseInvalidParameters.selector);
        receiver = new MockReceiver(address(vault), address(wnative), address(0), address(this));
    }

    function test_Initialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        receiver.initialize(address(this));
    }

    function test_Fuzz_SetAdapter(
        uint64 destChainSelector1,
        address adapter1,
        uint64 destChainSelector2,
        address adapter2
    ) public {
        vm.assume(destChainSelector1 != destChainSelector2);

        assertEq(receiver.getAdapter(destChainSelector1), address(0), "test_Fuzz_SetAdapter::1");
        assertEq(receiver.getAdapter(destChainSelector2), address(0), "test_Fuzz_SetAdapter::2");

        receiver.setAdapter(destChainSelector1, adapter1);

        assertEq(receiver.getAdapter(destChainSelector1), adapter1, "test_Fuzz_SetAdapter::3");
        assertEq(receiver.getAdapter(destChainSelector2), address(0), "test_Fuzz_SetAdapter::4");

        receiver.setAdapter(destChainSelector2, adapter2);

        assertEq(receiver.getAdapter(destChainSelector1), adapter1, "test_Fuzz_SetAdapter::5");
        assertEq(receiver.getAdapter(destChainSelector2), adapter2, "test_Fuzz_SetAdapter::6");

        receiver.setAdapter(destChainSelector1, address(0));

        assertEq(receiver.getAdapter(destChainSelector1), address(0), "test_Fuzz_SetAdapter::7");
        assertEq(receiver.getAdapter(destChainSelector2), adapter2, "test_Fuzz_SetAdapter::8");

        receiver.setAdapter(destChainSelector2, address(0));

        assertEq(receiver.getAdapter(destChainSelector1), address(0), "test_Fuzz_SetAdapter::9");
        assertEq(receiver.getAdapter(destChainSelector2), address(0), "test_Fuzz_SetAdapter::10");

        receiver.setAdapter(destChainSelector1, adapter2);
        receiver.setAdapter(destChainSelector2, adapter1);

        assertEq(receiver.getAdapter(destChainSelector1), adapter2, "test_Fuzz_SetAdapter::11");
        assertEq(receiver.getAdapter(destChainSelector2), adapter1, "test_Fuzz_SetAdapter::12");
    }

    function test_Fuzz_CCIPReceive(
        bytes32 messageId,
        uint64 sourceChainSelector,
        bytes memory sender,
        uint256 amountIn,
        uint128 feeDtoO,
        bool payInLinkDtoO
    ) public {
        vm.assume(sender.length > 0);

        amountIn = bound(amountIn, 0, 100e18);
        feeDtoO = uint128(bound(feeDtoO, 0, 1e18));

        receiver.setAdapter(sourceChainSelector, address(adapter));
        receiver.setSender(sourceChainSelector, sender);

        Client.EVMTokenAmount[] memory tokenAmounts;

        if (!payInLinkDtoO || feeDtoO == 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(wnative), amount: amountIn + feeDtoO});

            wnative.deposit{value: amountIn + feeDtoO}();
            wnative.transfer(address(receiver), amountIn + feeDtoO);
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](2);

            tokenAmounts[0] = Client.EVMTokenAmount({token: address(wnative), amount: amountIn});
            tokenAmounts[1] = Client.EVMTokenAmount({token: address(link), amount: feeDtoO});

            wnative.deposit{value: amountIn}();
            wnative.transfer(address(receiver), amountIn);

            link.mint(address(receiver), feeDtoO);
        }

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: sourceChainSelector,
            sender: sender,
            data: FeeCodec.encodePackedDataMemory(l2Sender, amountIn, abi.encodePacked(feeDtoO, payInLinkDtoO)),
            destTokenAmounts: tokenAmounts
        });

        uint256 shares = vault.previewDeposit(amountIn);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(messageId), 0, "test_Fuzz_CCIPReceive::1");
        assertEq(wnative.balanceOf(address(receiver)), 0, "test_Fuzz_CCIPReceive::2");
        assertEq(wnative.balanceOf(address(vault)), 2e18 + amountIn, "test_Fuzz_CCIPReceive::3");
        assertEq(vault.balanceOf(address(receiver)), shares, "test_Fuzz_CCIPReceive::4");

        MockBridge bridge = MockBridge(adapter.BRIDGE());

        assertEq(
            bridge.data(),
            abi.encodeWithSelector(
                IBridgeAdapter.sendToken.selector,
                sourceChainSelector,
                l2Sender,
                shares,
                abi.encodePacked(feeDtoO, payInLinkDtoO)
            ),
            "test_Fuzz_CCIPReceive::5"
        );
        assertEq(bridge.value(), payInLinkDtoO ? 0 : feeDtoO, "test_Fuzz_CCIPReceive::6");
    }

    function test_Fuzz_Revert_CCIPReceive(
        bytes32 messageId,
        uint64 sourceChainSelector,
        bytes memory sender,
        uint256 amountIn,
        uint128 feeDtoO
    ) public {
        vm.assume(sender.length > 0);

        amountIn = bound(amountIn, 0, 100e18);
        feeDtoO = uint128(bound(feeDtoO, 1, 1e18));

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(wnative), amount: amountIn + feeDtoO});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: sourceChainSelector,
            sender: sender,
            data: FeeCodec.encodePackedDataMemory(l2Sender, amountIn, abi.encode(feeDtoO)),
            destTokenAmounts: tokenAmounts
        });

        vm.expectRevert(ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverOnlyCCIPRouter.selector);
        receiver.ccipReceive(message);

        vm.prank(ccipRouter);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICCIPDefensiveReceiverUpgradeable.CCIPDefensiveReceiverUnsupportedChain.selector, sourceChainSelector
            )
        );
        receiver.ccipReceive(message);

        receiver.setSender(sourceChainSelector, sender);

        message.destTokenAmounts = new Client.EVMTokenAmount[](0);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::1"
        );

        vm.expectRevert(ICustomReceiver.CustomReceiverInvalidTokenAmounts.selector);
        receiver.retryFailedMessage(message);

        message.destTokenAmounts = new Client.EVMTokenAmount[](3);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::2"
        );

        vm.expectRevert(ICustomReceiver.CustomReceiverInvalidTokenAmounts.selector);
        receiver.retryFailedMessage(message);

        message.destTokenAmounts = tokenAmounts;
        message.data = FeeCodec.encodePackedDataMemory(l2Sender, amountIn + 1, abi.encodePacked(feeDtoO, false));

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::3"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustomReceiver.CustomReceiverInvalidTokenAmount.selector, amountIn + feeDtoO, amountIn + 1 + feeDtoO
            )
        );
        receiver.retryFailedMessage(message);

        message.data = FeeCodec.encodePackedDataMemory(l2Sender, amountIn, abi.encodePacked(feeDtoO + 1, false));

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::4"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustomReceiver.CustomReceiverInvalidTokenAmount.selector, amountIn + feeDtoO, amountIn + feeDtoO + 1
            )
        );
        receiver.retryFailedMessage(message);

        tokenAmounts = new Client.EVMTokenAmount[](2);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(wnative), amount: amountIn});
        tokenAmounts[1] = Client.EVMTokenAmount({token: address(link), amount: feeDtoO});

        message.destTokenAmounts = tokenAmounts;
        message.data = FeeCodec.encodePackedDataMemory(l2Sender, amountIn + 1, abi.encodePacked(feeDtoO, true));

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::5"
        );

        vm.expectRevert(
            abi.encodeWithSelector(ICustomReceiver.CustomReceiverInvalidTokenAmount.selector, amountIn, amountIn + 1)
        );
        receiver.retryFailedMessage(message);

        message.data = FeeCodec.encodePackedDataMemory(l2Sender, amountIn, abi.encodePacked(feeDtoO + 1, true));

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::6"
        );

        vm.expectRevert(
            abi.encodeWithSelector(ICustomReceiver.CustomReceiverInvalidFeeAmount.selector, feeDtoO + 1, feeDtoO)
        );
        receiver.retryFailedMessage(message);

        message.data = FeeCodec.encodePackedDataMemory(l2Sender, amountIn, abi.encodePacked(feeDtoO, false));

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::7"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(receiver), 0, amountIn + feeDtoO
            )
        );
        receiver.retryFailedMessage(message);

        wnative.deposit{value: amountIn + feeDtoO}();
        wnative.transfer(address(receiver), amountIn + feeDtoO);

        vm.prank(ccipRouter);
        receiver.ccipReceive(message);

        assertEq(
            receiver.getFailedMessageHash(messageId), keccak256(abi.encode(message)), "test_Fuzz_Revert_CCIPReceive::8"
        );

        vm.expectRevert(abi.encodeWithSelector(ICustomReceiver.CustomReceiverNoAdapter.selector, sourceChainSelector));
        receiver.retryFailedMessage(message);
    }
}

contract MockBridge {
    bytes public data;
    uint256 public value;

    function sendToken(uint64, address, uint256, bytes memory) public payable {
        data = msg.data;
        value = msg.value;
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}

contract MockAdapter {
    address public immutable BRIDGE;

    constructor() {
        BRIDGE = address(new MockBridge());
    }

    fallback() external {
        (bool s,) = BRIDGE.call{value: address(this).balance}(msg.data);
        require(s);
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}

contract MockVault is ERC4626 {
    constructor(address wnative) ERC4626(IERC20(wnative)) ERC20("Vault wNative", "vwNATIVE") {}

    function depositNative(address receiver) public payable returns (uint256) {
        uint256 assets = msg.value;

        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);

        IWNative(asset()).deposit{value: assets}();
        _mint(receiver, shares);

        return shares;
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}

contract MockReceiver is CustomReceiver {
    address public immutable VAULT_TOKEN;

    constructor(address vaultToken, address wnative, address ccipRouter, address initialAdmin)
        CustomReceiver(wnative)
        CCIPBaseUpgradeable(ccipRouter)
    {
        VAULT_TOKEN = vaultToken;

        initialize(initialAdmin);
    }

    function initialize(address initialAdmin) public initializer {
        __CustomReceiver_init_unchained();
        __CustomReceiver_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _stakeToken(uint256 amount) internal override returns (uint256) {
        return MockVault(VAULT_TOKEN).depositNative{value: amount}(address(this));
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
