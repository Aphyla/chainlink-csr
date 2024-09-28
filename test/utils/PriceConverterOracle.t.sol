// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/utils/PriceConverterOracle.sol";
import "../../contracts/utils/PriceOracle.sol";
import "../mocks/MockDataFeed.sol";
import "../mocks/MockPriceOracle.sol";

contract PriceConverterOracleTest is Test {
    PriceConverterOracle public priceConverterOracle;

    MockPriceOracle public priceOracleA;
    MockPriceOracle public priceOracleB;

    function setUp() public {
        priceOracleA = new MockPriceOracle();
        priceOracleB = new MockPriceOracle();

        priceConverterOracle = new PriceConverterOracle(address(priceOracleA), address(priceOracleB));

        vm.label(address(priceOracleA), "priceOracleA");
        vm.label(address(priceOracleB), "priceOracleB");
        vm.label(address(priceConverterOracle), "priceConverterOracle");
    }

    function test_Constructor() public {
        priceConverterOracle = new PriceConverterOracle(address(1), address(2)); // to fix coverage

        assertEq(priceConverterOracle.BASE_PRICE_ORACLE(), address(1), "test_Constructor::1");
        assertEq(priceConverterOracle.QUOTE_PRICE_ORACLE(), address(2), "test_Constructor::2");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleInvalidParameters.selector);
        new PriceConverterOracle(address(0), address(1));

        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleInvalidParameters.selector);
        new PriceConverterOracle(address(1), address(0));

        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleInvalidParameters.selector);
        new PriceConverterOracle(address(0), address(0));
    }

    function test_Fuzz_GetLatestAnswer(uint256 priceA, uint256 priceB) public {
        priceA = bound(priceA, 1, type(uint256).max);
        priceB = bound(priceB, priceA >= 1e18 ? 1 : (1e18 - 1) / priceA + 1, type(uint256).max / priceA);

        priceOracleA.setLatestAnswer(priceA);
        priceOracleB.setLatestAnswer(priceB);

        assertEq(priceConverterOracle.getLatestAnswer(), priceA * priceB / 1e18, "test_Fuzz_GetLatestAnswer::1");

        priceOracleA.setLatestAnswer(priceB);
        priceOracleB.setLatestAnswer(priceA);

        assertEq(priceConverterOracle.getLatestAnswer(), priceA * priceB / 1e18, "test_Fuzz_GetLatestAnswer::2");
    }

    function test_Fuzz_Revert_GetLatestAnswer(uint256 priceA, uint256 priceB) public {
        priceOracleA.setLatestAnswer(bound(priceA, 2, type(uint256).max));
        priceOracleB.setLatestAnswer(
            bound(priceB, (type(uint256).max - 1) / (priceOracleA.getLatestAnswer() - 1) + 1, type(uint256).max)
        );

        vm.expectRevert(); // Revert with EVM overflows
        priceConverterOracle.getLatestAnswer();

        priceA = bound(priceA, 1, 1e18 - 1);
        priceB = bound(priceB, 0, 1e18 / priceA - 1);

        priceOracleA.setLatestAnswer(priceA);
        priceOracleB.setLatestAnswer(priceB);

        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleInvalidPrice.selector);
        priceConverterOracle.getLatestAnswer();

        priceOracleA.setLatestAnswer(priceB);
        priceOracleB.setLatestAnswer(priceA);

        vm.expectRevert(IPriceConverterOracle.PriceConverterOracleInvalidPrice.selector);
        priceConverterOracle.getLatestAnswer();
    }
}
