// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/utils/PriceOracle.sol";
import "../mocks/MockDataFeed.sol";

contract PriceOracleTest is Test {
    PriceOracle public priceOracle8;
    MockDataFeed public aggregator8;
    bool public priceOracle8IsInverse = false;
    uint32 public priceOracle8Heartbeat = 1 hours;
    uint8 public priceOracle8Decimals = 8;

    PriceOracle public priceOracle18;
    MockDataFeed public aggregator18;
    bool public priceOracle18IsInverse = true;
    uint32 public priceOracle18Heartbeat = 24 hours;
    uint8 public priceOracle18Decimals = 18;

    function setUp() public {
        aggregator8 = new MockDataFeed(priceOracle8Decimals);
        aggregator18 = new MockDataFeed(priceOracle18Decimals);

        priceOracle8 = new PriceOracle(address(aggregator8), priceOracle8IsInverse, priceOracle8Heartbeat);
        priceOracle18 = new PriceOracle(address(aggregator18), priceOracle18IsInverse, priceOracle18Heartbeat);

        vm.label(address(aggregator8), "aggregator8");
        vm.label(address(priceOracle8), "priceOracle8");
        vm.label(address(aggregator18), "aggregator18");
        vm.label(address(priceOracle18), "priceOracle18");
    }

    function test_Constructor() public {
        priceOracle8 = new PriceOracle(address(aggregator8), priceOracle8IsInverse, priceOracle8Heartbeat);

        assertEq(priceOracle8.AGGREGATOR(), address(aggregator8), "test_Constructor::1");
        assertEq(priceOracle8.IS_INVERSE(), priceOracle8IsInverse, "test_Constructor::2");
        assertEq(priceOracle8.HEARTBEAT(), priceOracle8Heartbeat, "test_Constructor::3");
        assertEq(priceOracle8.DECIMALS(), priceOracle8Decimals, "test_Constructor::4");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(IPriceOracle.PriceOracleInvalidParameters.selector);
        new PriceOracle(address(0), false, 0);
    }

    function test_GetParameters() public view {
        assertEq(priceOracle8.AGGREGATOR(), address(aggregator8), "test_GetParameters::1");
        assertEq(priceOracle8.IS_INVERSE(), priceOracle8IsInverse, "test_GetParameters::2");
        assertEq(priceOracle8.HEARTBEAT(), priceOracle8Heartbeat, "test_GetParameters::3");
        assertEq(priceOracle8.DECIMALS(), priceOracle8Decimals, "test_GetParameters::4");

        assertEq(priceOracle18.AGGREGATOR(), address(aggregator18), "test_GetParameters::5");
        assertEq(priceOracle18.IS_INVERSE(), priceOracle18IsInverse, "test_GetParameters::6");
        assertEq(priceOracle18.HEARTBEAT(), priceOracle18Heartbeat, "test_GetParameters::7");
        assertEq(priceOracle18.DECIMALS(), priceOracle18Decimals, "test_GetParameters::8");
    }

    function test_Fuzz_GetLatestAnswer(int256 price8, int256 price18, uint256 updatedAt8, uint256 updatedAt18) public {
        vm.warp(365 days);

        int256 sprice8 = bound(price8, 1, int256(type(uint256).max / 1e18));
        int256 sprice18 = bound(price18, 1, int256(10 ** (18 + priceOracle18Decimals)));

        updatedAt8 = bound(updatedAt8, block.timestamp - priceOracle8Heartbeat, block.timestamp);
        updatedAt18 = bound(updatedAt18, block.timestamp - priceOracle18Heartbeat, block.timestamp);

        aggregator8.set(sprice8, 1, 0, updatedAt8, 1);
        aggregator18.set(sprice18, 1, 0, updatedAt18, 1);

        assertEq(
            priceOracle8.getLatestAnswer(),
            uint256(sprice8) * 10 ** (18 - priceOracle8Decimals),
            "test_Fuzz_GetLatestAnswer::1"
        );
        assertEq(
            priceOracle18.getLatestAnswer(),
            10 ** (18 + priceOracle18Decimals) / uint256(sprice18),
            "test_Fuzz_GetLatestAnswer::2"
        );
    }

    function test_Fuzz_Revert_GetLatestAnswer(int256 price, uint256 updatedAt) public {
        vm.warp(365 days);

        int256 sprice = bound(price, type(int256).min, 0);

        aggregator8.set(sprice, 0, 0, 0, 0);
        aggregator18.set(sprice, 0, 0, 0, 0);

        vm.expectRevert(IPriceOracle.PriceOracleInvalidPrice.selector);
        priceOracle8.getLatestAnswer();

        vm.expectRevert(IPriceOracle.PriceOracleInvalidPrice.selector);
        priceOracle18.getLatestAnswer();

        aggregator8.set(
            int256(10 ** priceOracle8Decimals),
            0,
            0,
            bound(updatedAt, 0, block.timestamp - priceOracle8Heartbeat - 1),
            0
        );
        aggregator18.set(
            int256(10 ** priceOracle18Decimals),
            0,
            0,
            bound(updatedAt, 0, block.timestamp - priceOracle18Heartbeat - 1),
            0
        );

        vm.expectRevert(IPriceOracle.PriceOracleStalePrice.selector);
        priceOracle8.getLatestAnswer();

        vm.expectRevert(IPriceOracle.PriceOracleStalePrice.selector);
        priceOracle18.getLatestAnswer();

        sprice = bound(price, int256(type(uint256).max / 1e18) + 1, type(int256).max);

        aggregator8.set(sprice, 0, 0, block.timestamp, 0);

        vm.expectRevert(); // Revert with EVM overflows
        priceOracle8.getLatestAnswer();

        sprice = bound(price, int256(10 ** (18 + priceOracle18Decimals)) + 1, type(int256).max);

        aggregator18.set(sprice, 0, 0, block.timestamp, 0);

        vm.expectRevert(IPriceOracle.PriceOracleInvalidPrice.selector);
        priceOracle18.getLatestAnswer();

        MockDataFeed aggregator = new MockDataFeed(36);
        PriceOracle priceOracle = new PriceOracle(address(aggregator), false, 1);

        aggregator.set(bound(price, 1, 1e18 - 1), 0, 0, block.timestamp, 0);

        vm.expectRevert(IPriceOracle.PriceOracleInvalidPrice.selector);
        priceOracle.getLatestAnswer();
    }
}
