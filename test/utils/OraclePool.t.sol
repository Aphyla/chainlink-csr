// SPDX-License-Identifier: Apache-2.0
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
    MockERC20 public tokenOut;
    MockERC20 public tokenIn;

    address public sender = makeAddr("sender");
    uint96 fee = 0.1e18;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        dataFeed = new MockDataFeed(18);
        priceOracle = new PriceOracle(address(dataFeed), false, 1 hours, address(this));
        tokenIn = new MockERC20("TokenIn", "TI", 18);
        tokenOut = new MockERC20("TokenOut", "TO", 18);
        oraclePool =
            new OraclePool(sender, address(tokenIn), address(tokenOut), address(priceOracle), fee, address(this));

        vm.label(address(dataFeed), "dataFeed");
        vm.label(address(priceOracle), "priceOracle");
        vm.label(address(tokenOut), "tokenOut");
        vm.label(address(tokenIn), "tokenIn");
        vm.label(address(oraclePool), "oraclePool");
    }

    function test_Constructor() public {
        oraclePool =
            new OraclePool(sender, address(tokenIn), address(tokenOut), address(priceOracle), fee, address(this)); // to fix coverage

        assertEq(oraclePool.SENDER(), sender, "test_Constructor::1");
        assertEq(oraclePool.TOKEN_IN(), address(tokenIn), "test_Constructor::2");
        assertEq(oraclePool.TOKEN_OUT(), address(tokenOut), "test_Constructor::3");
        assertEq(oraclePool.getOracle(), address(priceOracle), "test_Constructor::4");
        assertEq(oraclePool.getFee(), fee, "test_Constructor::5");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(IOraclePool.OraclePoolInvalidParameters.selector);
        oraclePool =
            new OraclePool(address(0), address(tokenIn), address(tokenOut), address(priceOracle), fee, address(this));

        vm.expectRevert(IOraclePool.OraclePoolInvalidParameters.selector);
        oraclePool = new OraclePool(sender, address(0), address(tokenOut), address(priceOracle), fee, address(this));

        vm.expectRevert(IOraclePool.OraclePoolInvalidParameters.selector);
        oraclePool = new OraclePool(sender, address(tokenIn), address(0), address(priceOracle), fee, address(this));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        oraclePool = new OraclePool(sender, address(tokenIn), address(tokenOut), address(priceOracle), fee, address(0));
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

    function test_Fuzz_Revert_GetFee(uint96 newFee) public {
        newFee = uint96(bound(newFee, 1e18 + 1, type(uint96).max));

        vm.expectRevert(IOraclePool.OraclePoolFeeTooHigh.selector);
        oraclePool.setFee(newFee);
    }

    function test_Fuzz_Swap(uint256 price, uint256 amountA, uint256 amountB) public {
        price = bound(price, 0.01e18, 100e18);
        amountA = bound(amountA, 0.01e18, 100e18);
        amountB = bound(amountB, 0.01e18, 100e18);

        tokenOut.mint(address(oraclePool), ((amountA + amountB) * 1e18) / price);

        dataFeed.set(int256(price), 1, 0, block.timestamp, 1);

        tokenIn.mint(alice, amountA);
        tokenIn.mint(bob, amountB);

        vm.prank(alice);
        tokenIn.transfer(address(sender), amountA);

        vm.startPrank(sender);
        tokenIn.approve(address(oraclePool), amountA);
        oraclePool.swap(alice, amountA, amountA * (1e18 - fee) / price);
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(address(oraclePool)), amountA, "test_Fuzz_Swap::1");
        assertGe(tokenOut.balanceOf(alice), amountA * (1e18 - fee) / price, "test_Fuzz_Swap::2");

        vm.prank(bob);
        tokenIn.transfer(address(sender), amountB);

        vm.startPrank(sender);
        tokenIn.approve(address(oraclePool), amountB);
        oraclePool.swap(bob, amountB, amountB * (1e18 - fee) / price);
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(address(oraclePool)), amountA + amountB, "test_Fuzz_Swap::3");
        assertGe(tokenOut.balanceOf(bob), amountB * (1e18 - fee) / price, "test_Fuzz_Swap::4");
    }

    function test_Fuzz_Revert_Swap(address msgSender, uint256 price, uint256 amountIn) public {
        vm.assume(msgSender != sender);

        price = bound(price, 0.01e18, 100e18);
        amountIn = bound(amountIn, 0.01e18, 100e18);

        dataFeed.set(int256(price), 1, 0, block.timestamp, 1);

        uint256 feeAmount = amountIn * oraclePool.getFee() / 1e18;
        uint256 amountOut = (amountIn - feeAmount) * 1e18 / price;

        vm.prank(msgSender);
        vm.expectRevert(abi.encodeWithSelector(IOraclePool.OraclePoolUnauthorizedAccount.selector, msgSender));
        oraclePool.swap(address(0), 0, 0);

        vm.startPrank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(IOraclePool.OraclePoolInsufficientAmountOut.selector, amountOut, amountOut + 1)
        );
        oraclePool.swap(alice, amountIn, amountOut + 1);

        vm.expectRevert(abi.encodeWithSelector(IOraclePool.OraclePoolInsufficientTokenOut.selector, amountOut, 0));
        oraclePool.swap(alice, amountIn, amountOut);

        tokenIn.mint(sender, 3 * amountIn);
        tokenOut.mint(address(oraclePool), 3 * amountOut);

        tokenIn.approve(address(oraclePool), 3 * amountIn);
        oraclePool.swap(alice, amountIn, amountOut);

        dataFeed.set(int256(price - 1), 1, 0, block.timestamp, 1);

        vm.expectRevert(abi.encodeWithSelector(IOraclePool.OraclePoolInvalidPrice.selector, price - 1, price));
        oraclePool.swap(alice, amountIn, amountOut);

        assertEq(tokenOut.balanceOf(alice), amountOut, "test_Fuzz_Revert_Swap::1");

        price = bound(price, price + 1, 200e18);
        dataFeed.set(int256(price), 1, 0, block.timestamp, 1);

        feeAmount = amountIn * oraclePool.getFee() / 1e18;
        amountOut = (amountIn - feeAmount) * 1e18 / price;

        oraclePool.swap(bob, amountIn, amountOut);

        assertEq(tokenOut.balanceOf(bob), amountOut, "test_Fuzz_Revert_Swap::2");
        vm.stopPrank();
    }

    function test_Revert_Swap() public {
        oraclePool.setOracle(address(0));

        vm.expectRevert(IOraclePool.OraclePoolZeroAmountIn.selector);
        vm.prank(sender);
        oraclePool.swap(address(0), 0, 0);

        vm.expectRevert(IOraclePool.OraclePoolOracleNotSet.selector);
        vm.prank(sender);
        oraclePool.swap(address(0), 1, 0);
    }

    function test_Fuzz_Pull(uint256 amount) public {
        amount = bound(amount, 0.01e18, 100e18);

        tokenIn.mint(address(sender), amount);

        tokenOut.mint(address(oraclePool), amount);

        dataFeed.set(1e18, 1, 0, block.timestamp, 1);
        oraclePool.setFee(0);

        vm.startPrank(sender);
        tokenIn.approve(address(oraclePool), amount);
        oraclePool.swap(alice, amount, amount);

        assertEq(tokenIn.balanceOf(address(oraclePool)), amount, "test_Fuzz_Pull::1");

        oraclePool.pull(address(tokenIn), amount);
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(address(oraclePool)), 0, "test_Fuzz_Pull::2");
        assertEq(tokenIn.balanceOf(sender), amount, "test_Fuzz_Pull::3");
    }

    function test_Fuzz_Revert_Pull(address msgSender, uint256 amount) public {
        vm.assume(msgSender != sender);

        amount = bound(amount, 0, type(uint256).max - 1);

        tokenIn.mint(address(oraclePool), amount);

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(IOraclePool.OraclePoolInsufficientToken.selector, tokenIn, amount + 1, amount)
        );
        oraclePool.pull(address(tokenIn), amount + 1);

        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(IOraclePool.OraclePoolPullNotAllowed.selector, tokenOut));
        oraclePool.pull(address(tokenOut), amount + 1);

        vm.prank(msgSender);
        vm.expectRevert(abi.encodeWithSelector(IOraclePool.OraclePoolUnauthorizedAccount.selector, msgSender));
        oraclePool.pull(address(0), 0);
    }

    function test_Sweep() public {
        tokenOut.mint(address(oraclePool), 1e18);

        assertEq(tokenOut.balanceOf(address(oraclePool)), 1e18, "test_Sweep::1");
        assertEq(tokenOut.balanceOf(address(this)), 0, "test_Sweep::2");

        oraclePool.sweep(address(tokenOut), address(this), 1e18);

        assertEq(tokenOut.balanceOf(address(oraclePool)), 0, "test_Sweep::3");
        assertEq(tokenOut.balanceOf(address(this)), 1e18, "test_Sweep::4");

        tokenIn.mint(address(sender), 1e18);
        tokenOut.mint(address(oraclePool), 1e18);

        dataFeed.set(1e18, 1, 0, block.timestamp, 1);
        oraclePool.setFee(0);

        vm.startPrank(sender);
        tokenIn.approve(address(oraclePool), 1e18);
        oraclePool.swap(alice, 1e18, 1e18);
        vm.stopPrank();

        assertEq(tokenIn.balanceOf(address(oraclePool)), 1e18, "test_Sweep::5");
        assertEq(tokenIn.balanceOf(address(this)), 0, "test_Sweep::6");

        oraclePool.sweep(address(tokenIn), address(this), 1e18);

        assertEq(tokenIn.balanceOf(address(oraclePool)), 0, "test_Sweep::7");
        assertEq(tokenIn.balanceOf(address(this)), 1e18, "test_Sweep::8");

        oraclePool.sweep(address(tokenOut), address(this), 0);
        oraclePool.sweep(address(tokenIn), address(this), 0);
    }
}
