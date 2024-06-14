// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";
import "../mocks/MockDataFeed.sol";
import "../mocks/MockERC20.sol";

contract OraclePoolTest is Test {
    OraclePool public oraclePool;
    PriceOracle public priceOracle;
    MockDataFeed public dataFeed;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;

    address public sender = makeAddr("sender");
    uint96 fee = 0.1e18;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        dataFeed = new MockDataFeed(18);
        priceOracle = new PriceOracle(address(dataFeed), false, 1 hours, address(this));
        baseToken = new MockERC20("Base Token", "BT", 18);
        quoteToken = new MockERC20("Quote Token", "QT", 18);
        oraclePool =
            new OraclePool(sender, address(baseToken), address(quoteToken), address(priceOracle), fee, address(this));

        vm.label(address(dataFeed), "dataFeed");
        vm.label(address(priceOracle), "priceOracle");
        vm.label(address(baseToken), "baseToken");
        vm.label(address(quoteToken), "quoteToken");
        vm.label(address(oraclePool), "oraclePool");
    }

    function test_Fuzz_GetOracle(address oracleB) public {
        assertEq(oraclePool.getOracle(), address(priceOracle), "test_Fuzz_GetOracle::1");

        oraclePool.setOracle(oracleB);

        assertEq(oraclePool.getOracle(), oracleB, "test_Fuzz_GetOracle::2");

        oraclePool.setOracle(address(0));

        assertEq(oraclePool.getOracle(), address(0), "test_Fuzz_GetOracle::3");

        oraclePool.setOracle(address(priceOracle));

        assertEq(oraclePool.getOracle(), address(priceOracle), "test_Fuzz_GetOracle::4");
    }

    function test_Fuzz_GetFee(uint96 newFee) public {
        newFee = uint96(bound(newFee, 0, 1e18));

        assertEq(oraclePool.getFee(), fee, "test_Fuzz_GetFee::1");

        oraclePool.setFee(newFee);

        assertEq(oraclePool.getFee(), newFee, "test_Fuzz_GetFee::2");

        oraclePool.setFee(0);

        assertEq(oraclePool.getFee(), 0, "test_Fuzz_GetFee::3");

        oraclePool.setFee(fee);

        assertEq(oraclePool.getFee(), fee, "test_Fuzz_GetFee::4");
    }

    function test_Fuzz_Swap(uint256 price, uint256 amountA, uint256 amountB) public {
        price = bound(price, 0.01e18, 100e18);
        amountA = bound(amountA, 0.01e18, 100e18);
        amountB = bound(amountB, 0.01e18, 100e18);

        baseToken.mint(address(oraclePool), ((amountA + amountB) * 1e18) / price);

        dataFeed.set(int256(price), 1, 0, block.timestamp, 1);

        quoteToken.mint(alice, amountA);
        quoteToken.mint(bob, amountB);

        vm.prank(alice);
        quoteToken.transfer(address(oraclePool), amountA);

        vm.prank(sender);
        oraclePool.swap(alice, amountA * (1e18 - fee) / price);

        assertEq(quoteToken.balanceOf(address(oraclePool)), amountA, "test_Fuzz_Swap::1");
        assertEq(oraclePool.getQuoteReserves(), amountA, "test_Fuzz_Swap::2");
        assertGe(baseToken.balanceOf(alice), amountA * (1e18 - fee) / price, "test_Fuzz_Swap::3");

        vm.prank(bob);
        quoteToken.transfer(address(oraclePool), amountB);

        vm.prank(sender);
        oraclePool.swap(bob, amountB * (1e18 - fee) / price);

        assertEq(quoteToken.balanceOf(address(oraclePool)), amountA + amountB, "test_Fuzz_Swap::4");
        assertEq(oraclePool.getQuoteReserves(), amountA + amountB, "test_Fuzz_Swap::5");
        assertGe(baseToken.balanceOf(bob), amountB * (1e18 - fee) / price, "test_Fuzz_Swap::6");
    }

    function test_Fuzz_Revert_Swap(uint256 price, uint256 amount) public {
        price = bound(price, 0.01e18, 100e18);
        amount = bound(amount, 0.01e18, 100e18);

        dataFeed.set(int256(price), 1, 0, block.timestamp, 1);
        quoteToken.mint(address(oraclePool), amount);

        uint256 quoteFeeAmount = amount * oraclePool.getFee() / 1e18;
        uint256 baseAmount = (amount - quoteFeeAmount) * 1e18 / price;

        vm.startPrank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(IOraclePool.OraclePoolInsufficientOutputAmount.selector, baseAmount, baseAmount + 1)
        );
        oraclePool.swap(alice, baseAmount + 1);

        vm.expectRevert(abi.encodeWithSelector(IOraclePool.OraclePoolInsufficientBaseBalance.selector, baseAmount, 0));
        oraclePool.swap(alice, baseAmount);
        vm.stopPrank();
    }

    function test_Revert_Swap() public {
        oraclePool.setOracle(address(0));

        vm.expectRevert(IOraclePool.OraclePoolNoOracle.selector);
        vm.prank(sender);
        oraclePool.swap(address(0), 0);
    }

    function test_Fuzz_TransferQuoteReserve(uint256 amount) public {
        amount = bound(amount, 0.01e18, 100e18);

        quoteToken.mint(address(oraclePool), amount);
        baseToken.mint(address(oraclePool), amount);

        dataFeed.set(1e18, 1, 0, block.timestamp, 1);
        oraclePool.setFee(0);

        vm.prank(sender);
        oraclePool.swap(alice, amount);

        assertEq(quoteToken.balanceOf(address(oraclePool)), amount, "test_Fuzz_TransferQuoteReserve::1");
        assertEq(oraclePool.getQuoteReserves(), amount, "test_Fuzz_TransferQuoteReserve::2");

        vm.prank(sender);
        oraclePool.transferQuoteToken(sender, amount);

        assertEq(quoteToken.balanceOf(address(oraclePool)), 0, "test_Fuzz_TransferQuoteReserve::3");
        assertEq(quoteToken.balanceOf(sender), amount, "test_Fuzz_TransferQuoteReserve::4");
        assertEq(oraclePool.getQuoteReserves(), 0, "test_Fuzz_TransferQuoteReserve::5");
    }

    function test_Fuzz_Revert_TransferQuoteReserve(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max - 1);

        quoteToken.mint(address(oraclePool), amount);

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(IOraclePool.OraclePoolInsufficientQuoteBalance.selector, amount + 1, amount)
        );
        oraclePool.transferQuoteToken(sender, amount + 1);
    }

    function test_Sweep() public {
        baseToken.mint(address(oraclePool), 1e18);

        oraclePool.sweep(address(baseToken), address(this), 1e18);

        assertEq(baseToken.balanceOf(address(oraclePool)), 0, "test_Sweep::1");
        assertEq(baseToken.balanceOf(address(this)), 1e18, "test_Sweep::2");
        assertEq(oraclePool.getQuoteReserves(), 0, "test_Sweep::3");

        quoteToken.mint(address(oraclePool), 1e18);
        baseToken.mint(address(oraclePool), 1e18);

        dataFeed.set(1e18, 1, 0, block.timestamp, 1);
        oraclePool.setFee(0);

        vm.prank(sender);
        oraclePool.swap(alice, 1e18);

        assertEq(quoteToken.balanceOf(address(oraclePool)), 1e18, "test_Sweep::4");
        assertEq(oraclePool.getQuoteReserves(), 1e18, "test_Sweep::5");

        oraclePool.sweep(address(quoteToken), address(this), 1e18);

        assertEq(quoteToken.balanceOf(address(oraclePool)), 0, "test_Sweep::6");
        assertEq(quoteToken.balanceOf(address(this)), 1e18, "test_Sweep::7");
        assertEq(oraclePool.getQuoteReserves(), 0, "test_Sweep::8");
    }
}
