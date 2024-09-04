// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/adapters/BridgeAdapter.sol";
import "../../contracts/adapters/BaseAdapterL1toL2.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockReceiver.sol";

contract BaseAdapterL1toL2Test is Test {
    MockReceiver public receiver;
    BaseAdapterL1toL2 public adapter;

    MockERC20 public l1Token;
    MockL1StandardBridge public l1StandardBridge;

    address public l2Token = makeAddr("l2Token");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        receiver = new MockReceiver();

        l1Token = new MockERC20("L1 Token", "L1T", 18);
        l1StandardBridge = new MockL1StandardBridge();

        adapter = new BaseAdapterL1toL2(address(l1StandardBridge), address(l1Token), l2Token, address(receiver));

        receiver.setAdapter(address(adapter));
    }

    function test_Constructor() public {
        adapter = new BaseAdapterL1toL2(address(l1StandardBridge), address(l1Token), l2Token, address(receiver)); // to fix coverage

        assertEq(address(adapter.L1_STANDARD_BRIDGE()), address(l1StandardBridge), "test_Constructor::1");
        assertEq(address(adapter.L1_TOKEN()), address(l1Token), "test_Constructor::2");
        assertEq(address(adapter.L2_TOKEN()), l2Token, "test_Constructor::3");
        assertEq(address(adapter.DELEGATOR()), address(receiver), "test_Constructor::4");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(BaseAdapterL1toL2.BaseAdapterL1toL2InvalidParameters.selector);
        adapter = new BaseAdapterL1toL2(address(0), address(l1Token), l2Token, address(receiver));

        vm.expectRevert(BaseAdapterL1toL2.BaseAdapterL1toL2InvalidParameters.selector);
        adapter = new BaseAdapterL1toL2(address(l1StandardBridge), address(0), l2Token, address(receiver));

        vm.expectRevert(BaseAdapterL1toL2.BaseAdapterL1toL2InvalidParameters.selector);
        adapter = new BaseAdapterL1toL2(address(l1StandardBridge), address(l1Token), address(0), address(receiver));

        vm.expectRevert(IBridgeAdapter.BridgeAdapterInvalidParameters.selector);
        adapter = new BaseAdapterL1toL2(address(l1StandardBridge), address(l1Token), l2Token, address(0));
    }

    function test_Fuzz_SendToken(uint256 amount, uint32 l2Gas) public {
        bytes memory feeData = FeeCodec.encodeBaseL1toL2(l2Gas);

        receiver.sendToken(uint64(0), recipient, amount, feeData);

        assertEq(
            l1StandardBridge.msgData(),
            abi.encodeWithSelector(
                IBaseL1StandardBridge.depositERC20To.selector, l1Token, l2Token, recipient, amount, l2Gas, new bytes(0)
            ),
            "test_Fuzz_SendToken::1"
        );
        assertEq(
            IERC20(l1Token).allowance(address(receiver), address(l1StandardBridge)), amount, "test_Fuzz_SendToken::2"
        );
    }

    function test_Fuzz_Revert_SendToken(address msgSender, uint128 amount, uint32 l2Gas) public {
        amount = uint128(bound(amount, 1, type(uint128).max));

        bytes memory feeData = abi.encodePacked(uint128(0), true, uint32(0));

        vm.expectRevert(BaseAdapterL1toL2.BaseAdapterL1toL2InvalidFeeToken.selector);
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = abi.encodePacked(uint128(amount), false, uint32(0));

        vm.expectRevert(abi.encodeWithSelector(BaseAdapterL1toL2.BaseAdapterL1toL2InvalidFeeAmount.selector, amount, 0));
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = FeeCodec.encodeBaseL1toL2(l2Gas);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(msgSender);
        adapter.sendToken(uint64(0), recipient, amount, feeData);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(address(receiver));
        adapter.sendToken(uint64(0), recipient, amount, feeData);
    }
}

contract MockL1StandardBridge {
    bytes public msgData;

    function depositERC20To(address, address, address, uint256, uint32, bytes memory) external {
        msgData = msg.data;
    }

    function test() public pure {}
}
