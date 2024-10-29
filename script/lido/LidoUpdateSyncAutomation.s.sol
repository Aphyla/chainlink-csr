// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LidoParameters.sol";
import "../ScriptHelper.sol";

import "contracts/libraries/FeeCodec.sol";
import "contracts/automations/SyncAutomation.sol";

contract LidoTransferOwnershipScript is ScriptHelper, LidoParameters {
    uint256 public ethereumForkId;
    uint256 public arbitrumForkId;
    uint256 public optimismForkId;
    uint256 public baseForkId;

    function setUp() public {
        ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"));
        arbitrumForkId = vm.createFork(vm.rpcUrl("arbitrum"));
        optimismForkId = vm.createFork(vm.rpcUrl("optimism"));
        baseForkId = vm.createFork(vm.rpcUrl("base"));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("LIDO_DEPLOYER_PRIVATE_KEY");

        {
            vm.selectFork(arbitrumForkId);

            SyncAutomation syncAutomation = SyncAutomation(payable(ARBITRUM_SYNC_AUTOMATION));

            vm.startBroadcast(deployerPrivateKey);
            syncAutomation.setAmounts(ARBITRUM_MIN_SYNC_AMOUNT, ARBITRUM_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(ARBITRUM_MIN_SYNC_DELAY);
            syncAutomation.setFeeOtoD(
                FeeCodec.encodeCCIP(
                    ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                )
            );
            vm.stopBroadcast();
        }

        {
            vm.selectFork(optimismForkId);

            SyncAutomation syncAutomation = SyncAutomation(payable(OPTIMISM_SYNC_AUTOMATION));

            vm.startBroadcast(deployerPrivateKey);
            syncAutomation.setAmounts(OPTIMISM_MIN_SYNC_AMOUNT, OPTIMISM_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(OPTIMISM_MIN_SYNC_DELAY);
            syncAutomation.setFeeOtoD(
                FeeCodec.encodeCCIP(
                    ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                )
            );
            vm.stopBroadcast();
        }

        {
            vm.selectFork(baseForkId);

            SyncAutomation syncAutomation = SyncAutomation(payable(BASE_SYNC_AUTOMATION));

            vm.startBroadcast(deployerPrivateKey);
            syncAutomation.setAmounts(BASE_MIN_SYNC_AMOUNT, BASE_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(BASE_MIN_SYNC_DELAY);
            syncAutomation.setFeeOtoD(
                FeeCodec.encodeCCIP(
                    ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                )
            );
            vm.stopBroadcast();
        }
    }
}
