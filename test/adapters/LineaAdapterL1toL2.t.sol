// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/adapters/BridgeAdapter.sol";
import "../../contracts/adapters/LineaAdapterL1toL2.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockReceiver.sol";

contract LineaAdapterL1toL2Test is Test {
    MockReceiver public receiver;
    LineaAdapterL1toL2 public adapter;

    MockERC20 public l1Token;
    MockL1TokenBridge public l1TokenBridge;

    address public l2Token = makeAddr("l2Token");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        receiver = new MockReceiver();

        l1Token = new MockERC20("L1 Token", "L1T", 18);
        l1TokenBridge = new MockL1TokenBridge();

        adapter = new LineaAdapterL1toL2(address(l1TokenBridge), address(l1Token), address(receiver));

        receiver.setAdapter(address(adapter));
    }

    function test_Constructor() public {
        adapter = new LineaAdapterL1toL2(address(l1TokenBridge), address(l1Token), address(receiver)); // to fix coverage

        assertEq(address(adapter.TOKEN_BRIDGE()), address(l1TokenBridge), "test_Constructor::1");
        assertEq(address(adapter.TOKEN()), address(l1Token), "test_Constructor::2");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(LineaAdapterL1toL2.LineaAdapterL1toL2InvalidParameters.selector);
        adapter = new LineaAdapterL1toL2(address(0), address(l1Token), address(receiver));

        vm.expectRevert(LineaAdapterL1toL2.LineaAdapterL1toL2InvalidParameters.selector);
        adapter = new LineaAdapterL1toL2(address(l1TokenBridge), address(0), address(receiver));

        vm.expectRevert(IBridgeAdapter.BridgeAdapterInvalidParameters.selector);
        adapter = new LineaAdapterL1toL2(address(l1TokenBridge), address(l1Token), address(0));
    }

    function test_Fuzz_SendToken(uint256 amount) public {
        bytes memory feeData = FeeCodec.encodeLineaL1toL2();

        receiver.sendToken(uint64(0), recipient, amount, feeData);

        assertEq(l1TokenBridge.msgValue(), 0, "test_Fuzz_SendToken::1");
        assertEq(
            l1TokenBridge.msgData(),
            abi.encodeWithSelector(ILineaTokenBridge.bridgeToken.selector, address(l1Token), amount, recipient),
            "test_Fuzz_SendToken::2"
        );
        assertEq(IERC20(l1Token).allowance(address(receiver), address(l1TokenBridge)), amount, "test_Fuzz_SendToken::3");
    }

    function test_Fuzz_Revert_SendToken(address msgSender) public {
        uint256 amount = 1e18;

        bytes memory feeData = abi.encodePacked(uint128(0), true);

        vm.expectRevert(LineaAdapterL1toL2.LineaAdapterL1toL2InvalidFeeToken.selector);
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = FeeCodec.encodeLineaL1toL2();

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(msgSender);
        adapter.sendToken(uint64(0), recipient, amount, feeData);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(address(receiver));
        adapter.sendToken(uint64(0), recipient, amount, feeData);
    }
}

contract MockL1TokenBridge {
    bytes public msgData;
    uint256 public msgValue;

    function bridgeToken(address, uint256, address) external payable {
        msgData = msg.data;
        msgValue = msg.value;
    }

    function test() public pure {}
}
