// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../contracts/libraries/TokenHelper.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockWNative.sol";

contract TokenHelperTest is Test {
    MockContract public mock;
    MockERC20 public mockERC20;
    MockWNative public mockWNative;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    function setUp() public {
        mock = new MockContract();
        mockERC20 = new MockERC20("MockERC20", "MERC20", 18);
        mockWNative = new MockWNative();
    }

    function test_Fuzz_TransferNative(uint256 amount) public {
        amount = bound(amount, 0, type(uint128).max);

        vm.deal(address(mock), amount);

        mock.transferNative(alice, 2 * amount / 3);
        mock.transferNative(bob, amount / 3);

        assertEq(address(alice).balance, 2 * amount / 3, "test_Fuzz_TransferNative::1");
        assertEq(address(bob).balance, amount / 3, "test_Fuzz_TransferNative::2");
    }

    function test_Fuzz_Revert_TransferNative(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        vm.expectRevert(TokenHelper.TokenHelperNativeTransferFailed.selector);
        mock.transferNative(alice, amount);

        vm.deal(address(mock), amount);

        vm.expectRevert(TokenHelper.TokenHelperNativeTransferFailed.selector);
        mock.transferNative(address(this), amount);

        mock.transferNative(alice, amount);

        assertEq(address(alice).balance, amount, "test_Fuzz_Revert_TransferNative::1");

        mock.transferNative(address(this), 0);
    }

    function test_Fuzz_Transfer(uint256 amountERC20, uint256 amountNative) public {
        amountERC20 = bound(amountERC20, 0, type(uint128).max);
        amountNative = bound(amountNative, 0, type(uint128).max);

        assertEq(mockERC20.balanceOf(alice), 0, "test_Fuzz_Transfer::1");
        assertEq(mockERC20.balanceOf(bob), 0, "test_Fuzz_Transfer::2");
        assertEq(address(alice).balance, 0, "test_Fuzz_Transfer::3");
        assertEq(address(bob).balance, 0, "test_Fuzz_Transfer::4");

        vm.deal(address(mock), amountNative);
        mockERC20.mint(address(mock), amountERC20);

        mock.transfer(address(mockERC20), alice, 2 * amountERC20 / 3);
        mock.transfer(address(mockERC20), bob, amountERC20 / 3);

        assertEq(mockERC20.balanceOf(alice), 2 * amountERC20 / 3, "test_Fuzz_Transfer::5");
        assertEq(mockERC20.balanceOf(bob), amountERC20 / 3, "test_Fuzz_Transfer::6");
        assertEq(address(alice).balance, 0, "test_Fuzz_Transfer::7");
        assertEq(address(bob).balance, 0, "test_Fuzz_Transfer::8");

        mock.transfer(address(0), alice, amountNative / 3);
        mock.transfer(address(0), bob, 2 * amountNative / 3);

        assertEq(mockERC20.balanceOf(alice), 2 * amountERC20 / 3, "test_Fuzz_Transfer::9");
        assertEq(mockERC20.balanceOf(bob), amountERC20 / 3, "test_Fuzz_Transfer::10");
        assertEq(address(alice).balance, amountNative / 3, "test_Fuzz_Transfer::11");
        assertEq(address(bob).balance, 2 * amountNative / 3, "test_Fuzz_Transfer::12");
    }

    function test_Fuzz_Revert_Transfer(uint256 amountERC20, uint256 amountNative) public {
        amountERC20 = bound(amountERC20, 2, type(uint128).max);
        amountNative = bound(amountNative, 2, type(uint128).max);

        vm.expectRevert(TokenHelper.TokenHelperNativeTransferFailed.selector);
        mock.transfer(address(0), alice, amountNative);

        vm.deal(address(mock), amountNative);

        vm.expectRevert(TokenHelper.TokenHelperNativeTransferFailed.selector);
        mock.transfer(address(0), address(this), amountNative);

        mock.transfer(address(0), alice, amountNative);

        assertEq(address(alice).balance, amountNative, "test_Fuzz_Revert_Transfer::1");

        mock.transfer(address(0), address(this), 0);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(mock), 0, amountERC20)
        );
        mock.transfer(address(mockERC20), alice, amountERC20);

        mockERC20.mint(address(mock), amountERC20 - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(mock), amountERC20 - 1, amountERC20
            )
        );
        mock.transfer(address(mockERC20), alice, amountERC20);
    }

    function test_Fuzz_RefundExcessNative(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        vm.deal(address(this), 2 * amount);

        mock.refundExcessNative(alice);

        assertEq(address(alice).balance, 0, "test_Fuzz_RefundExcessNative::1");

        mock.refundExcessNative{value: amount}(bob);

        assertEq(address(bob).balance, amount, "test_Fuzz_RefundExcessNative::2");

        mock.sendAndRefundExcessNative{value: amount}(bob, amount / 2, alice);

        assertEq(address(alice).balance, amount - amount / 2, "test_Fuzz_RefundExcessNative::3");
        assertEq(address(bob).balance, amount + amount / 2, "test_Fuzz_RefundExcessNative::4");
    }

    function test_Fuzz_Revert_RefundExcessNative(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        vm.deal(address(this), amount);

        vm.expectRevert(TokenHelper.TokenHelperNativeTransferFailed.selector);
        mock.refundExcessNative{value: amount}(address(this));
    }
}

contract MockContract {
    receive() external payable {}

    function transfer(address token, address to, uint256 amount) external payable {
        TokenHelper.transfer(token, to, amount);
    }

    function refundExcessNative(address to) external payable {
        TokenHelper.refundExcessNative(to);
    }

    function sendAndRefundExcessNative(address to, uint256 amount, address refundTo) external payable {
        TokenHelper.transferNative(to, amount);
        TokenHelper.refundExcessNative(refundTo);
    }

    function transferNative(address to, uint256 amount) external payable {
        TokenHelper.transferNative(to, amount);
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
