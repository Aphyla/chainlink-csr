// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../script/lido/LidoUpgradeL2ToCustomSenderReferral.s.sol";
import "../../../contracts/senders/CustomSender.sol";

contract fork_LidoUpgradeL2ToCustomSenderReferralScriptTest is Test, LidoParameters {
    LidoUpgradeL2ToCustomSenderReferral public script;

    address alice = makeAddr("alice");
    address referral = makeAddr("referral");

    function setUp() public {
        script = new LidoUpgradeL2ToCustomSenderReferral();
        script.setUp();
    }

    function test_Deploy() public {
        LidoUpgradeL2ToCustomSenderReferral.L2Contracts[] memory l2Contracts = script.run();

        {
            vm.selectFork(script.arbitrumForkId());
            assertEq(l2Contracts[0].chainName, "Arbitrum", "test_Deploy::1");

            vm.deal(alice, 1e18);

            CustomSenderReferral sender = CustomSenderReferral(ARBITRUM_SENDER_PROXY);

            vm.prank(alice);
            sender.fastStakeReferral{value: 1e18}(address(0), 1e18, 0.8e18, referral);
            assertGt(IERC20(ARBITRUM_WSTETH_TOKEN).balanceOf(alice), 0.8e18, "test_Deploy::2");
        }

        {
            vm.selectFork(script.optimismForkId());
            assertEq(l2Contracts[1].chainName, "Optimism", "test_Deploy::3");

            vm.deal(alice, 1e18);

            CustomSenderReferral sender = CustomSenderReferral(OPTIMISM_SENDER_PROXY);

            vm.prank(alice);
            sender.fastStakeReferral{value: 1e18}(address(0), 1e18, 0.8e18, referral);
            assertGt(IERC20(OPTIMISM_WSTETH_TOKEN).balanceOf(alice), 0.8e18, "test_Deploy::4");
        }

        {
            vm.selectFork(script.baseForkId());
            assertEq(l2Contracts[2].chainName, "Base", "test_Deploy::5");

            vm.deal(alice, 1e18);

            CustomSenderReferral sender = CustomSenderReferral(BASE_SENDER_PROXY);

            vm.prank(alice);
            sender.fastStakeReferral{value: 1e18}(address(0), 1e18, 0.8e18, referral);
            assertGt(IERC20(BASE_WSTETH_TOKEN).balanceOf(alice), 0.8e18, "test_Deploy::6");
        }
    }
}
