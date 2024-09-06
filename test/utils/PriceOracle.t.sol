// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/utils/PriceOracle.sol";
import "../mocks/MockDataFeed.sol";

contract PriceOracleTest is Test {
    PriceOracle public priceOracle;
    MockDataFeed public dataFeed8;
    MockDataFeed public dataFeed18;

    function setUp() public {
        dataFeed8 = new MockDataFeed(8);
        dataFeed18 = new MockDataFeed(18);
        priceOracle = new PriceOracle(address(dataFeed8), false, 1 hours, address(this));

        vm.label(address(dataFeed8), "dataFeed8");
        vm.label(address(dataFeed18), "dataFeed18");
        vm.label(address(priceOracle), "priceOracle");
    }

    function test_Constructor() public {
        priceOracle = new PriceOracle(address(dataFeed8), false, 1 hours, address(this)); // to fix coverage

        (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

        assertEq(dataFeed, address(dataFeed8), "test_Constructor::1");
        assertEq(isInverse, false, "test_Constructor::2");
        assertEq(heartbeat, 1 hours, "test_Constructor::3");
        assertEq(decimals, 8, "test_Constructor::4");
    }

    function test_GetParameters() public {
        (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

        assertEq(dataFeed, address(dataFeed8), "test_GetParameters::1");
        assertEq(isInverse, false, "test_GetParameters::2");
        assertEq(heartbeat, 1 hours, "test_GetParameters::3");
        assertEq(decimals, 8, "test_GetParameters::4");

        priceOracle.setAggregator(address(dataFeed18), true);

        (dataFeed, isInverse, heartbeat, decimals) = priceOracle.getOracleParameters();

        assertEq(dataFeed, address(dataFeed18), "test_GetParameters::5");
        assertEq(isInverse, true, "test_GetParameters::6");
        assertEq(heartbeat, 1 hours, "test_GetParameters::7");
        assertEq(decimals, 18, "test_GetParameters::8");

        priceOracle.setHeartbeat(2 hours);

        (dataFeed, isInverse, heartbeat, decimals) = priceOracle.getOracleParameters();

        assertEq(dataFeed, address(dataFeed18), "test_GetParameters::9");
        assertEq(isInverse, true, "test_GetParameters::10");
        assertEq(heartbeat, 2 hours, "test_GetParameters::11");
        assertEq(decimals, 18, "test_GetParameters::12");

        priceOracle.setAggregator(address(0), false);

        (dataFeed, isInverse, heartbeat, decimals) = priceOracle.getOracleParameters();

        assertEq(dataFeed, address(0), "test_GetParameters::13");
        assertEq(isInverse, false, "test_GetParameters::14");
        assertEq(heartbeat, 2 hours, "test_GetParameters::15");
        assertEq(decimals, 0, "test_GetParameters::16");
    }

    function test_Fuzz_GetLatestAnswer(int256 price, uint256 updatedAt) public {
        vm.warp(365 days);

        int256 sprice = bound(price, 1, int256(type(uint256).max / 1e18));
        updatedAt = bound(updatedAt, block.timestamp - 1 hours, block.timestamp);

        dataFeed8.set(sprice, 1, 0, updatedAt, 1);

        assertEq(priceOracle.getLatestAnswer(), uint256(sprice) * 10 ** (18 - 8), "test_Fuzz_GetLatestAnswer::1");

        dataFeed18.set(sprice, 1, 0, updatedAt, 1);
        priceOracle.setAggregator(address(dataFeed18), false);

        assertEq(priceOracle.getLatestAnswer(), uint256(sprice) * 10 ** (18 - 18), "test_Fuzz_GetLatestAnswer::2");

        sprice = bound(price, 1, 10 ** (18 + 8));

        dataFeed8.set(sprice, 1, 0, block.timestamp, 1);
        priceOracle.setAggregator(address(dataFeed8), true);

        assertEq(priceOracle.getLatestAnswer(), 10 ** (18 + 8) / uint256(sprice), "test_Fuzz_GetLatestAnswer::3");

        sprice = bound(price, 1, 10 ** (18 + 18));

        dataFeed18.set(sprice, 1, 0, block.timestamp, 1);
        priceOracle.setAggregator(address(dataFeed18), true);

        assertEq(priceOracle.getLatestAnswer(), 10 ** (18 + 18) / uint256(sprice), "test_Fuzz_GetLatestAnswer::4");
    }

    function test_Fuzz_Revert_GetLatestAnswer(int256 price, uint256 updatedAt) public {
        vm.warp(365 days);

        price = bound(price, type(int256).min, 0);

        dataFeed8.set(price, 0, 0, 0, 0);

        vm.expectRevert(IPriceOracle.PriceOracleInvalidPrice.selector);
        priceOracle.getLatestAnswer();

        updatedAt = bound(updatedAt, 0, block.timestamp - 1 hours - 1);

        dataFeed8.set(1, 0, 0, updatedAt, 0);

        vm.expectRevert(IPriceOracle.PriceOracleStalePrice.selector);
        priceOracle.getLatestAnswer();

        price = bound(price, int256(type(uint256).max / 1e18) + 1, type(int256).max);

        dataFeed8.set(price, 0, 0, block.timestamp, 0);

        vm.expectRevert(); // Revert with EVM overflows
        priceOracle.getLatestAnswer();

        price = bound(price, 1e28 + 1, type(int256).max / 1e18);

        priceOracle.setAggregator(address(dataFeed8), true);

        vm.expectRevert(IPriceOracle.PriceOracleInvalidPrice.selector);
        priceOracle.getLatestAnswer();

        dataFeed8 = new MockDataFeed(36);
        priceOracle.setAggregator(address(dataFeed8), false);

        price = bound(price, 1, 1e18 - 1);

        dataFeed8.set(price, 0, 0, block.timestamp, 0);

        vm.expectRevert(IPriceOracle.PriceOracleInvalidPrice.selector);
        priceOracle.getLatestAnswer();
    }

    function test_Revert_GetLatestAnswer() public {
        priceOracle.setAggregator(address(0), false);

        vm.expectRevert(IPriceOracle.PriceOracleAggregatorNotSet.selector);
        priceOracle.getLatestAnswer();
    }
}
