// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/adapters/BridgeAdapter.sol";
import "../../contracts/adapters/FraxFerryAdapterL1toL2.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockReceiver.sol";

contract FraxFerryAdapterL1toL2Test is Test {
    MockReceiver public receiver;
    FraxFerryAdapterL1toL2 public adapter;

    MockERC20 public token;
    MockFraxFerry public fraxFerry;

    address public recipient = makeAddr("recipient");

    function setUp() public {
        receiver = new MockReceiver();

        token = new MockERC20("L1 Token", "L1T", 18);
        fraxFerry = new MockFraxFerry();

        adapter = new FraxFerryAdapterL1toL2(address(fraxFerry), address(token), address(receiver));

        receiver.setAdapter(address(adapter));
    }

    function test_Constructor() public {
        adapter = new FraxFerryAdapterL1toL2(address(fraxFerry), address(token), address(receiver)); // to fix coverage

        assertEq(address(adapter.FRAX_FERRY()), address(fraxFerry), "test_Constructor::1");
        assertEq(address(adapter.TOKEN()), address(token), "test_Constructor::2");
        assertEq(address(adapter.DELEGATOR()), address(receiver), "test_Constructor::3");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(FraxFerryAdapterL1toL2.FraxFerryAdapterL1toL2InvalidParameters.selector);
        adapter = new FraxFerryAdapterL1toL2(address(0), address(token), address(receiver));

        vm.expectRevert(FraxFerryAdapterL1toL2.FraxFerryAdapterL1toL2InvalidParameters.selector);
        adapter = new FraxFerryAdapterL1toL2(address(fraxFerry), address(0), address(receiver));

        vm.expectRevert(IBridgeAdapter.BridgeAdapterInvalidParameters.selector);
        adapter = new FraxFerryAdapterL1toL2(address(fraxFerry), address(token), address(0));
    }

    function test_Fuzz_SendToken(uint256 amount) public {
        bytes memory feeData = FeeCodec.encodeFraxFerryL1toL2();

        receiver.sendToken(uint64(0), recipient, amount, feeData);

        assertEq(
            fraxFerry.msgData(),
            abi.encodeWithSelector(IFraxFerry.embarkWithRecipient.selector, amount, recipient),
            "test_Fuzz_SendToken::1"
        );
        assertEq(IERC20(token).allowance(address(receiver), address(fraxFerry)), amount, "test_Fuzz_SendToken::2");
    }

    function test_Fuzz_Revert_SendToken(address msgSender, uint128 amount) public {
        amount = uint128(bound(amount, 1, type(uint128).max));

        bytes memory feeData = abi.encodePacked(uint128(0), true);

        vm.expectRevert(abi.encodeWithSelector(FraxFerryAdapterL1toL2.FraxFerryAdapterL1toL2InvalidFeeToken.selector));
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = abi.encodePacked(amount, false);

        vm.expectRevert(
            abi.encodeWithSelector(FraxFerryAdapterL1toL2.FraxFerryAdapterL1toL2InvalidFeeAmount.selector, amount, 0)
        );
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = FeeCodec.encodeFraxFerryL1toL2();

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(msgSender);
        adapter.sendToken(uint64(0), recipient, amount, feeData);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(address(receiver));
        adapter.sendToken(uint64(0), recipient, amount, feeData);
    }
}

contract MockFraxFerry {
    bytes public msgData;

    function embarkWithRecipient(uint256, address) public {
        msgData = msg.data;
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
