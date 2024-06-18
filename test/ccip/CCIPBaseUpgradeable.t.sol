// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../contracts/ccip/CCIPBaseUpgradeable.sol";

contract CCIPBaseUpgradeableTest is Test {
    MockCCIPUpgradeable public ccip;

    function test_Fuzz_Initialize(address ccipRouter) public {
        ccip = new MockCCIPUpgradeable(ccipRouter);

        assertEq(ccip.CCIP_ROUTER(), ccipRouter, "test_Fuzz_Initialize::1");

        ccip.initialize();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ccip.initialize();
    }

    function test_Fuzz_InitializeUnchained(address ccipRouter) public {
        ccip = new MockCCIPUpgradeable(ccipRouter);

        assertEq(ccip.CCIP_ROUTER(), ccipRouter, "test_Fuzz_InitializeUnchained::1");

        ccip.initializeUnchained();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ccip.initializeUnchained();
    }

    function test_Fuzz_BadInitialize(address ccipRouter) public {
        ccip = new MockCCIPUpgradeable(ccipRouter);

        assertEq(ccip.CCIP_ROUTER(), ccipRouter, "test_Fuzz_BadInitialize::1");

        vm.expectRevert(Initializable.NotInitializing.selector);
        ccip.badInitialize();
    }
}

contract MockCCIPUpgradeable is CCIPBaseUpgradeable {
    constructor(address ccipRouter) CCIPBaseUpgradeable(ccipRouter) {}

    function initialize() public initializer {
        __CCIPBase_init();
    }

    function initializeUnchained() public initializer {
        __CCIPBase_init_unchained();
    }

    function badInitialize() public {
        __CCIPBase_init();
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
