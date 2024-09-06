// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/adapters/BridgeAdapter.sol";
import "../../contracts/adapters/OptimismLegacyAdapterL1toL2.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockReceiver.sol";

contract OptimismLegacyAdapterL1toL2Test is Test {
    MockReceiver public receiver;
    OptimismLegacyAdapterL1toL2 public adapter;

    MockERC20 public l1Token;
    MockERC20Bridge public l1ERC20Bridge;

    address public l2Token = makeAddr("l2Token");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        receiver = new MockReceiver();

        l1Token = new MockERC20("L1 Token", "L1T", 18);
        l1ERC20Bridge = new MockERC20Bridge(address(l1Token), l2Token);

        adapter = new OptimismLegacyAdapterL1toL2(address(l1ERC20Bridge), address(receiver));

        receiver.setAdapter(address(adapter));
    }

    function test_Constructor() public {
        adapter = new OptimismLegacyAdapterL1toL2(address(l1ERC20Bridge), address(receiver)); // to fix coverage

        assertEq(address(adapter.L1_ERC20_BRIDGE()), address(l1ERC20Bridge), "test_Constructor::1");
        assertEq(address(adapter.L1_TOKEN()), address(l1Token), "test_Constructor::2");
        assertEq(address(adapter.L2_TOKEN()), l2Token, "test_Constructor::3");
        assertEq(address(adapter.DELEGATOR()), address(receiver), "test_Constructor::4");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(OptimismLegacyAdapterL1toL2.OptimismLegacyAdapterL1toL2InvalidParameters.selector);
        adapter = new OptimismLegacyAdapterL1toL2(address(0), address(receiver));

        vm.expectRevert(IBridgeAdapter.BridgeAdapterInvalidParameters.selector);
        adapter = new OptimismLegacyAdapterL1toL2(address(l1ERC20Bridge), address(0));
    }

    function test_Fuzz_SendToken(uint256 amount, uint32 l2Gas) public {
        bytes memory feeData = FeeCodec.encodeOptimismL1toL2(l2Gas);

        receiver.sendToken(uint64(0), recipient, amount, feeData);

        assertEq(
            l1ERC20Bridge.msgData(),
            abi.encodeWithSelector(
                IOptimismL1ERC20TokenBridge.depositERC20To.selector,
                l1Token,
                l2Token,
                recipient,
                amount,
                l2Gas,
                new bytes(0)
            ),
            "test_Fuzz_SendToken::1"
        );
        assertEq(IERC20(l1Token).allowance(address(receiver), address(l1ERC20Bridge)), amount, "test_Fuzz_SendToken::2");
    }

    function test_Fuzz_Revert_SendToken(address msgSender, uint128 amount, uint32 l2Gas) public {
        amount = uint128(bound(amount, 1, type(uint128).max));

        bytes memory feeData = abi.encodePacked(uint128(0), true, uint32(0));

        vm.expectRevert(
            abi.encodeWithSelector(OptimismLegacyAdapterL1toL2.OptimismLegacyAdapterL1toL2InvalidFeeToken.selector)
        );
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = abi.encodePacked(amount, false, uint32(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                OptimismLegacyAdapterL1toL2.OptimismLegacyAdapterL1toL2InvalidFeeAmount.selector, amount, 0
            )
        );
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = FeeCodec.encodeOptimismL1toL2(l2Gas);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(msgSender);
        adapter.sendToken(uint64(0), recipient, amount, feeData);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(address(receiver));
        adapter.sendToken(uint64(0), recipient, amount, feeData);
    }
}

contract MockERC20Bridge is ERC20 {
    address public l1Token;
    address public l2Token;

    bytes public msgData;

    constructor(address l1Token_, address l2Token_) ERC20("Mock L2 Token", "ML2T") {
        l1Token = l1Token_;
        l2Token = l2Token_;
    }

    function depositERC20To(address, address, address, uint256, uint32, bytes memory) external {
        msgData = msg.data;
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
