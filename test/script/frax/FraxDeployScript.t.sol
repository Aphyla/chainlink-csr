// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../script/frax/FraxDeploy.s.sol";

contract fork_FraxDeployScriptTest is Test, FraxParameters {
    FraxDeployScript public script;

    function setUp() public {
        script = new FraxDeployScript();
        script.setUp();
    }

    function test_Deploy() public {
        (FraxDeployScript.L1Contracts memory l1Contracts, FraxDeployScript.L2Contracts[] memory l2Contracts) =
            script.run();

        address deployer = script.deployer();

        vm.selectFork(script.ethereumForkId());

        {
            FraxCustomReceiver receiver = FraxCustomReceiver(payable(l1Contracts.receiver.proxy));

            assertEq(receiver.SFRXETH(), ETHEREUM_SFRXETH_TOKEN, "test_Deploy::1");
            assertEq(receiver.WNATIVE(), ETHEREUM_WETH_TOKEN, "test_Deploy::2");
            assertEq(receiver.CCIP_ROUTER(), ETHEREUM_CCIP_ROUTER, "test_Deploy::3");
            assertEq(receiver.hasRole(receiver.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::4");
            assertEq(receiver.getAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR), l1Contracts.arbitrumAdapter, "test_Deploy::5");
            assertEq(receiver.getAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR), l1Contracts.optimismAdapter, "test_Deploy::6");
            assertEq(
                receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR),
                abi.encode(l2Contracts[0].sender.proxy),
                "test_Deploy::7"
            );
            assertEq(
                receiver.getSender(OPTIMISM_CCIP_CHAIN_SELECTOR),
                abi.encode(l2Contracts[1].sender.proxy),
                "test_Deploy::8"
            );
            assertEq(_getProxyAdmin(l1Contracts.receiver.proxy), l1Contracts.receiver.proxyAdmin, "test_Deploy::9");
            assertEq(ProxyAdmin(l1Contracts.receiver.proxyAdmin).owner(), deployer, "test_Deploy::10");
            assertEq(
                _getProxyImplementation(l1Contracts.receiver.proxy),
                l1Contracts.receiver.implementation,
                "test_Deploy::11"
            );

            FraxFerryAdapterL1toL2 arbAdapter = FraxFerryAdapterL1toL2(l1Contracts.arbitrumAdapter);

            assertEq(arbAdapter.FRAX_FERRY(), ETHEREUM_TO_ARBITRUM_FRAX_FERRY, "test_Deploy::12");
            assertEq(arbAdapter.TOKEN(), ETHEREUM_SFRXETH_TOKEN, "test_Deploy::13");

            FraxFerryAdapterL1toL2 optAdapter = FraxFerryAdapterL1toL2(l1Contracts.optimismAdapter);

            assertEq(optAdapter.FRAX_FERRY(), ETHEREUM_TO_OPTIMISM_FRAX_FERRY, "test_Deploy::14");
            assertEq(optAdapter.TOKEN(), ETHEREUM_SFRXETH_TOKEN, "test_Deploy::15");
        }

        vm.selectFork(script.arbitrumForkId());

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            assertEq(dataFeed, ARBITRUM_SFRXETH_FRXETH_DATAFEED, "test_Deploy::16");
            assertEq(isInverse, ARBITRUM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE, "test_Deploy::17");
            assertEq(heartbeat, ARBITRUM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT, "test_Deploy::18");
            assertEq(AggregatorV3Interface(dataFeed).decimals(), decimals, "test_Deploy::19");

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            assertEq(oraclePool.SENDER(), l2Contracts[0].sender.proxy, "test_Deploy::20");
            assertEq(oraclePool.TOKEN_IN(), ARBITRUM_WETH_TOKEN, "test_Deploy::21");
            assertEq(oraclePool.TOKEN_OUT(), ARBITRUM_SFRXETH_TOKEN, "test_Deploy::22");
            assertEq(oraclePool.getOracle(), l2Contracts[0].priceOracle, "test_Deploy::23");
            assertEq(oraclePool.getFee(), ARBITRUM_ORACLE_POOL_FEE, "test_Deploy::24");
            assertEq(oraclePool.owner(), deployer, "test_Deploy::25");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            assertEq(sender.WNATIVE(), ARBITRUM_WETH_TOKEN, "test_Deploy::26");
            assertEq(sender.LINK_TOKEN(), ARBITRUM_LINK_TOKEN, "test_Deploy::27");
            assertEq(sender.CCIP_ROUTER(), ARBITRUM_CCIP_ROUTER, "test_Deploy::28");
            assertEq(sender.getOraclePool(), l2Contracts[0].oraclePool, "test_Deploy::29");
            assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::30");
            assertEq(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), true, "test_Deploy::31");
            assertEq(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)),
                l1Contracts.receiver.proxy,
                "test_Deploy::32"
            );
            assertEq(_getProxyAdmin(l2Contracts[0].sender.proxy), l2Contracts[0].sender.proxyAdmin, "test_Deploy::33");
            assertEq(ProxyAdmin(l2Contracts[0].sender.proxyAdmin).owner(), deployer, "test_Deploy::34");
            assertEq(
                _getProxyImplementation(l2Contracts[0].sender.proxy),
                l2Contracts[0].sender.implementation,
                "test_Deploy::35"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            assertEq(syncAutomation.SENDER(), l2Contracts[0].sender.proxy, "test_Deploy::36");
            assertEq(syncAutomation.DEST_CHAIN_SELECTOR(), ETHEREUM_CCIP_CHAIN_SELECTOR, "test_Deploy::37");
            assertEq(syncAutomation.WNATIVE(), ARBITRUM_WETH_TOKEN, "test_Deploy::38");
            assertEq(syncAutomation.owner(), deployer, "test_Deploy::39");
            assertEq(syncAutomation.getLastExecution(), block.timestamp, "test_Deploy::40");
            assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Deploy::41");
        }

        vm.selectFork(script.optimismForkId());

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[1].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            assertEq(dataFeed, OPTIMISM_SFRXETH_FRXETH_DATAFEED, "test_Deploy::42");
            assertEq(isInverse, OPTIMISM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE, "test_Deploy::43");
            assertEq(heartbeat, OPTIMISM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT, "test_Deploy::44");
            assertEq(AggregatorV3Interface(dataFeed).decimals(), decimals, "test_Deploy::45");

            OraclePool oraclePool = OraclePool(l2Contracts[1].oraclePool);

            assertEq(oraclePool.SENDER(), l2Contracts[1].sender.proxy, "test_Deploy::46");
            assertEq(oraclePool.TOKEN_IN(), OPTIMISM_WETH_TOKEN, "test_Deploy::47");
            assertEq(oraclePool.TOKEN_OUT(), OPTIMISM_SFRXETH_TOKEN, "test_Deploy::48");
            assertEq(oraclePool.getOracle(), l2Contracts[1].priceOracle, "test_Deploy::49");
            assertEq(oraclePool.getFee(), OPTIMISM_ORACLE_POOL_FEE, "test_Deploy::50");
            assertEq(oraclePool.owner(), deployer, "test_Deploy::51");

            CustomSender sender = CustomSender(l2Contracts[1].sender.proxy);

            assertEq(sender.WNATIVE(), OPTIMISM_WETH_TOKEN, "test_Deploy::52");
            assertEq(sender.LINK_TOKEN(), OPTIMISM_LINK_TOKEN, "test_Deploy::53");
            assertEq(sender.CCIP_ROUTER(), OPTIMISM_CCIP_ROUTER, "test_Deploy::54");
            assertEq(sender.getOraclePool(), l2Contracts[1].oraclePool, "test_Deploy::55");
            assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::56");
            assertEq(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[1].syncAutomation), true, "test_Deploy::57");
            assertEq(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)),
                l1Contracts.receiver.proxy,
                "test_Deploy::58"
            );
            assertEq(_getProxyAdmin(l2Contracts[1].sender.proxy), l2Contracts[1].sender.proxyAdmin, "test_Deploy::59");
            assertEq(ProxyAdmin(l2Contracts[1].sender.proxyAdmin).owner(), deployer, "test_Deploy::60");
            assertEq(
                _getProxyImplementation(l2Contracts[1].sender.proxy),
                l2Contracts[1].sender.implementation,
                "test_Deploy::61"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[1].syncAutomation);

            assertEq(syncAutomation.SENDER(), l2Contracts[1].sender.proxy, "test_Deploy::62");
            assertEq(syncAutomation.DEST_CHAIN_SELECTOR(), ETHEREUM_CCIP_CHAIN_SELECTOR, "test_Deploy::63");
            assertEq(syncAutomation.WNATIVE(), OPTIMISM_WETH_TOKEN, "test_Deploy::64");
            assertEq(syncAutomation.owner(), deployer, "test_Deploy::65");
            assertEq(syncAutomation.getLastExecution(), block.timestamp, "test_Deploy::66");
            assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Deploy::67");
        }
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }

    function _getProxyImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT))));
    }
}
