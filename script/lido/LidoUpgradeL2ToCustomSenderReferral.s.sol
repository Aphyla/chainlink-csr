// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "./LidoParameters.sol";
import "../ScriptHelper.sol";
import "../../contracts/senders/CustomSenderReferral.sol";

contract LidoUpgradeL2ToCustomSenderReferral is ScriptHelper, LidoParameters {
    struct L2Contracts {
        string chainName;
        address implementation;
    }

    uint256 public arbitrumForkId;
    uint256 public optimismForkId;
    uint256 public baseForkId;

    function setUp() public {
        arbitrumForkId = vm.createFork(vm.rpcUrl("arbitrum"));
        optimismForkId = vm.createFork(vm.rpcUrl("optimism"));
        baseForkId = vm.createFork(vm.rpcUrl("base"));
    }

    function run() public returns (L2Contracts[] memory l2Contracts) {
        uint256 deployerPrivateKey = vm.envUint("LIDO_DEPLOYER_PRIVATE_KEY");

        l2Contracts = new L2Contracts[](3);

        L2Contracts memory arbContracts = l2Contracts[0];
        L2Contracts memory optContracts = l2Contracts[1];
        L2Contracts memory baseContracts = l2Contracts[2];

        arbContracts.chainName = "Arbitrum";
        optContracts.chainName = "Optimism";
        baseContracts.chainName = "Base";

        // Deploy contracts on Arbitrum
        {
            vm.selectFork(arbitrumForkId);
            vm.startBroadcast(deployerPrivateKey);

            arbContracts.implementation = address(
                new CustomSenderReferral(
                    ARBITRUM_WETH_TOKEN,
                    ARBITRUM_WETH_TOKEN,
                    ARBITRUM_LINK_TOKEN,
                    ARBITRUM_CCIP_ROUTER,
                    DEAD_ADDRESS,
                    DEAD_ADDRESS
                )
            );

            vm.stopBroadcast();
        }

        // Deploy contracts on Optimism
        {
            vm.selectFork(optimismForkId);
            vm.startBroadcast(deployerPrivateKey);

            optContracts.implementation = address(
                new CustomSenderReferral(
                    OPTIMISM_WETH_TOKEN,
                    OPTIMISM_WETH_TOKEN,
                    OPTIMISM_LINK_TOKEN,
                    OPTIMISM_CCIP_ROUTER,
                    DEAD_ADDRESS,
                    DEAD_ADDRESS
                )
            );

            vm.stopBroadcast();
        }

        // Deploy contracts on Base
        {
            vm.selectFork(baseForkId);
            vm.startBroadcast(deployerPrivateKey);

            baseContracts.implementation = address(
                new CustomSenderReferral(
                    BASE_WETH_TOKEN, BASE_WETH_TOKEN, BASE_LINK_TOKEN, BASE_CCIP_ROUTER, DEAD_ADDRESS, DEAD_ADDRESS
                )
            );

            vm.stopBroadcast();
        }

        // Upgrade contracts on Arbitrum
        {
            vm.selectFork(arbitrumForkId);
            vm.startBroadcast(deployerPrivateKey);

            ProxyAdmin(ARBITRUM_SENDER_PROXY_ADMIN).upgradeAndCall(
                ITransparentUpgradeableProxy(ARBITRUM_SENDER_PROXY), arbContracts.implementation, new bytes(0)
            );

            vm.stopBroadcast();
        }

        // Upgrade contracts on Optimism
        {
            vm.selectFork(optimismForkId);
            vm.startBroadcast(deployerPrivateKey);

            ProxyAdmin(OPTIMISM_SENDER_PROXY_ADMIN).upgradeAndCall(
                ITransparentUpgradeableProxy(OPTIMISM_SENDER_PROXY), optContracts.implementation, new bytes(0)
            );

            vm.stopBroadcast();
        }

        // Upgrade contracts on Base
        {
            vm.selectFork(baseForkId);
            vm.startBroadcast(deployerPrivateKey);

            ProxyAdmin(BASE_SENDER_PROXY_ADMIN).upgradeAndCall(
                ITransparentUpgradeableProxy(BASE_SENDER_PROXY), baseContracts.implementation, new bytes(0)
            );

            vm.stopBroadcast();
        }
    }
}
