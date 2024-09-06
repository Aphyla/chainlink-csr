// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/utils/PriceConverterOracle.sol";
import "../../contracts/utils/PriceOracle.sol";
import "../mocks/MockDataFeed.sol";

contract PriceConverterOracleTest is Test {
    PriceConverterOracle public priceConverterOracle;

    PriceOracle public priceOracleAB;
    PriceOracle public priceOracleBC;

    MockDataFeed public dataFeedAB;
    MockDataFeed public dataFeedBC;

    function setUp() public {
        dataFeedAB = new MockDataFeed(8);
        dataFeedBC = new MockDataFeed(18);

        priceOracleAB = new PriceOracle(address(dataFeedAB), false, 1 hours, address(this));
        priceOracleBC = new PriceOracle(address(dataFeedBC), false, 1 hours, address(this));

        priceConverterOracle = new PriceConverterOracle(address(0), address(0), address(this));

        vm.label(address(dataFeedAB), "dataFeedAB");
        vm.label(address(dataFeedBC), "dataFeedBC");
        vm.label(address(priceOracleAB), "priceOracleAB");
        vm.label(address(priceOracleBC), "priceOracleBC");
        vm.label(address(priceConverterOracle), "priceConverterOracle");
    }

    function test_Constructor() public {
        priceConverterOracle = new PriceConverterOracle(address(0), address(0), address(this)); // to fix coverage

        assertEq(priceConverterOracle.getBasePriceOracle(), address(0), "test_Constructor::1");
        assertEq(priceConverterOracle.getQuotePriceOracle(), address(0), "test_Constructor::2");
    }

    function test_Fuzz_GetPriceOracles(address oracleA, address oracleB) public {
        address baseOracle = priceConverterOracle.getBasePriceOracle();
        address quoteOracle = priceConverterOracle.getQuotePriceOracle();

        assertEq(baseOracle, address(0), "test_Fuzz_GetPriceOracles::1");
        assertEq(quoteOracle, address(0), "test_Fuzz_GetPriceOracles::2");

        priceConverterOracle.setBasePriceOracle(oracleA);

        baseOracle = priceConverterOracle.getBasePriceOracle();
        quoteOracle = priceConverterOracle.getQuotePriceOracle();

        assertEq(baseOracle, oracleA, "test_Fuzz_GetPriceOracles::3");
        assertEq(quoteOracle, address(0), "test_Fuzz_GetPriceOracles::4");

        priceConverterOracle.setQuotePriceOracle(oracleB);

        baseOracle = priceConverterOracle.getBasePriceOracle();
        quoteOracle = priceConverterOracle.getQuotePriceOracle();

        assertEq(baseOracle, oracleA, "test_Fuzz_GetPriceOracles::5");
        assertEq(quoteOracle, oracleB, "test_Fuzz_GetPriceOracles::6");

        priceConverterOracle.setBasePriceOracle(oracleB);

        baseOracle = priceConverterOracle.getBasePriceOracle();
        quoteOracle = priceConverterOracle.getQuotePriceOracle();

        assertEq(baseOracle, oracleB, "test_Fuzz_GetPriceOracles::7");
        assertEq(quoteOracle, oracleB, "test_Fuzz_GetPriceOracles::8");
    }

    function test_Fuzz_GetLatestAnswer(int256 priceAB, int256 priceBC) public {
        int256 spriceAB = bound(priceAB, 1, int256(type(uint256).max / 1e18));
        int256 spriceBC =
            bound(priceBC, (1e18 - 1) / (1e10 * spriceAB) + 1, int256(type(uint256).max / (1e18 * uint256(spriceAB))));
        spriceBC = spriceBC == 0 ? int256(1) : spriceBC;

        dataFeedAB.set(spriceAB, 0, 0, block.timestamp, 0);
        dataFeedBC.set(spriceBC, 0, 0, block.timestamp, 0);

        priceOracleAB.setAggregator(address(dataFeedAB), false);
        priceOracleBC.setAggregator(address(dataFeedBC), false);

        priceConverterOracle.setBasePriceOracle(address(priceOracleAB));
        priceConverterOracle.setQuotePriceOracle(address(priceOracleBC));

        assertEq(
            priceConverterOracle.getLatestAnswer(),
            uint256(spriceAB) * 1e10 * uint256(spriceBC) / 1e18,
            "test_Fuzz_GetLatestAnswer::1"
        );

        spriceAB = bound(priceAB, 1, 10 ** (18 + 8));
        spriceBC = bound(priceBC, 0, 1e18 / (1e26 / spriceAB));
        spriceBC = spriceBC == 0 ? int256(1) : spriceBC;

        dataFeedAB.set(spriceAB, 0, 0, block.timestamp, 0);
        dataFeedBC.set(spriceBC, 0, 0, block.timestamp, 0);

        priceOracleAB.setAggregator(address(dataFeedAB), true);
        priceOracleBC.setAggregator(address(dataFeedBC), true);

        assertEq(
            priceConverterOracle.getLatestAnswer(),
            (10 ** (18 + 8) / uint256(spriceAB)) * (10 ** (18 + 18) / uint256(spriceBC)) / 1e18,
            "test_Fuzz_GetLatestAnswer::2"
        );
    }

    function test_Fuzz_Revert_GetLatestAnswer(int256 priceAB, int256 priceBC) public {
        priceAB = bound(priceAB, 1, 1e8 - 1);
        priceBC = bound(priceBC, 0, 1e18 / (1e10 * priceAB) - 1);
        priceBC = priceBC == 0 ? int256(1) : priceBC;

        dataFeedAB.set(priceAB, 0, 0, block.timestamp, 0);
        dataFeedBC.set(priceBC, 0, 0, block.timestamp, 0);

        priceOracleAB.setAggregator(address(dataFeedAB), false);
        priceOracleBC.setAggregator(address(dataFeedBC), false);

        priceConverterOracle.setBasePriceOracle(address(priceOracleAB));
        priceConverterOracle.setQuotePriceOracle(address(priceOracleBC));

        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleInvalidPrice.selector);
        priceConverterOracle.getLatestAnswer();
    }

    function test_Revert_GetLatestAnswer() public {
        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleNoOracle.selector);
        priceConverterOracle.getLatestAnswer();

        priceConverterOracle.setBasePriceOracle(address(priceOracleAB));

        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleNoOracle.selector);
        priceConverterOracle.getLatestAnswer();

        priceConverterOracle.setQuotePriceOracle(address(priceOracleBC));
        priceConverterOracle.setBasePriceOracle(address(0));

        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleNoOracle.selector);
        priceConverterOracle.getLatestAnswer();
    }
}
