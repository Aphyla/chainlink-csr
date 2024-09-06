// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../script/lido/LidoDeploy.s.sol";

contract fork_LidoDeployScriptTest is Test, LidoParameters {
    LidoDeployScript public script;

    function setUp() public {
        script = new LidoDeployScript();
        script.setUp();
    }

    function test_Deploy() public {
        (LidoDeployScript.L1Contracts memory l1Contracts, LidoDeployScript.L2Contracts[] memory l2Contracts) =
            script.run();

        address deployer = script.deployer();

        vm.selectFork(script.ethereumForkId());

        {
            LidoCustomReceiver receiver = LidoCustomReceiver(payable(l1Contracts.receiver.proxy));

            assertEq(receiver.WSTETH(), ETHEREUM_WSTETH_TOKEN, "test_Deploy::1");
            assertEq(receiver.WNATIVE(), ETHEREUM_WETH_TOKEN, "test_Deploy::2");
            assertEq(receiver.CCIP_ROUTER(), ETHEREUM_CCIP_ROUTER, "test_Deploy::3");
            assertEq(receiver.hasRole(receiver.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::4");
            assertEq(receiver.getAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR), l1Contracts.arbitrumAdapter, "test_Deploy::5");
            assertEq(receiver.getAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR), l1Contracts.optimismAdapter, "test_Deploy::6");
            assertEq(receiver.getAdapter(BASE_CCIP_CHAIN_SELECTOR), l1Contracts.baseAdapter, "test_Deploy::7");
            assertEq(
                receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR),
                abi.encode(l2Contracts[0].sender.proxy),
                "test_Deploy::8"
            );
            assertEq(
                receiver.getSender(OPTIMISM_CCIP_CHAIN_SELECTOR),
                abi.encode(l2Contracts[1].sender.proxy),
                "test_Deploy::9"
            );
            assertEq(
                receiver.getSender(BASE_CCIP_CHAIN_SELECTOR), abi.encode(l2Contracts[2].sender.proxy), "test_Deploy::10"
            );
            assertEq(_getProxyAdmin(l1Contracts.receiver.proxy), l1Contracts.receiver.proxyAdmin, "test_Deploy::11");
            assertEq(ProxyAdmin(l1Contracts.receiver.proxyAdmin).owner(), deployer, "test_Deploy::12");
            assertEq(
                _getProxyImplementation(l1Contracts.receiver.proxy),
                l1Contracts.receiver.implementation,
                "test_Deploy::13"
            );

            ArbitrumLegacyAdapterL1toL2 arbAdapter = ArbitrumLegacyAdapterL1toL2(l1Contracts.arbitrumAdapter);

            assertEq(arbAdapter.L1_GATEWAY_ROUTER(), ETHEREUM_TO_ARBITRUM_ROUTER, "test_Deploy::14");
            assertEq(arbAdapter.L1_TOKEN(), ETHEREUM_WSTETH_TOKEN, "test_Deploy::15");
            assertEq(
                arbAdapter.L1_TOKEN_GATEWAY(),
                IArbitrumL1GatewayRouter(ETHEREUM_TO_ARBITRUM_ROUTER).l1TokenToGateway(ETHEREUM_WSTETH_TOKEN),
                "test_Deploy::16"
            );
            assertEq(arbAdapter.DELEGATOR(), l1Contracts.receiver.proxy, "test_Deploy::17");

            OptimismLegacyAdapterL1toL2 optAdapter = OptimismLegacyAdapterL1toL2(l1Contracts.optimismAdapter);

            assertEq(optAdapter.L1_ERC20_BRIDGE(), ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE, "test_Deploy::18");
            assertEq(
                optAdapter.L1_TOKEN(),
                IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).l1Token(),
                "test_Deploy::19"
            );
            assertEq(
                optAdapter.L2_TOKEN(),
                IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).l2Token(),
                "test_Deploy::20"
            );
            assertEq(optAdapter.DELEGATOR(), l1Contracts.receiver.proxy, "test_Deploy::21");

            BaseAdapterL1toL2 baseAdapter = BaseAdapterL1toL2(l1Contracts.baseAdapter);

            assertEq(baseAdapter.L1_STANDARD_BRIDGE(), ETHEREUM_TO_BASE_STANDARD_BRIDGE, "test_Deploy::22");
            assertEq(baseAdapter.L1_TOKEN(), ETHEREUM_WSTETH_TOKEN, "test_Deploy::23");
            assertEq(baseAdapter.L2_TOKEN(), BASE_WSTETH_TOKEN, "test_Deploy::24");
            assertEq(baseAdapter.DELEGATOR(), l1Contracts.receiver.proxy, "test_Deploy::25");
        }

        vm.selectFork(script.arbitrumForkId());

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            assertEq(dataFeed, ARBITRUM_WSTETH_STETH_DATAFEED, "test_Deploy::26");
            assertEq(isInverse, ARBITRUM_WSTETH_STETH_DATAFEED_IS_INVERSE, "test_Deploy::27");
            assertEq(heartbeat, ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT, "test_Deploy::28");
            assertEq(AggregatorV3Interface(dataFeed).decimals(), decimals, "test_Deploy::29");

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            assertEq(oraclePool.SENDER(), l2Contracts[0].sender.proxy, "test_Deploy::30");
            assertEq(oraclePool.TOKEN_IN(), ARBITRUM_WETH_TOKEN, "test_Deploy::31");
            assertEq(oraclePool.TOKEN_OUT(), ARBITRUM_WSTETH_TOKEN, "test_Deploy::32");
            assertEq(oraclePool.getOracle(), l2Contracts[0].priceOracle, "test_Deploy::33");
            assertEq(oraclePool.getFee(), ARBITRUM_ORACLE_POOL_FEE, "test_Deploy::34");
            assertEq(oraclePool.owner(), deployer, "test_Deploy::35");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            assertEq(sender.WNATIVE(), ARBITRUM_WETH_TOKEN, "test_Deploy::36");
            assertEq(sender.LINK_TOKEN(), ARBITRUM_LINK_TOKEN, "test_Deploy::37");
            assertEq(sender.CCIP_ROUTER(), ARBITRUM_CCIP_ROUTER, "test_Deploy::38");
            assertEq(sender.getOraclePool(), l2Contracts[0].oraclePool, "test_Deploy::39");
            assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::40");
            assertEq(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), true, "test_Deploy::41");
            assertEq(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)),
                l1Contracts.receiver.proxy,
                "test_Deploy::42"
            );
            assertEq(_getProxyAdmin(l2Contracts[0].sender.proxy), l2Contracts[0].sender.proxyAdmin, "test_Deploy::43");
            assertEq(ProxyAdmin(l2Contracts[0].sender.proxyAdmin).owner(), deployer, "test_Deploy::44");
            assertEq(
                _getProxyImplementation(l2Contracts[0].sender.proxy),
                l2Contracts[0].sender.implementation,
                "test_Deploy::45"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            assertEq(syncAutomation.SENDER(), l2Contracts[0].sender.proxy, "test_Deploy::46");
            assertEq(syncAutomation.DEST_CHAIN_SELECTOR(), ETHEREUM_CCIP_CHAIN_SELECTOR, "test_Deploy::47");
            assertEq(syncAutomation.WNATIVE(), ARBITRUM_WETH_TOKEN, "test_Deploy::48");
            assertEq(syncAutomation.owner(), deployer, "test_Deploy::49");
            assertEq(syncAutomation.getLastExecution(), block.timestamp, "test_Deploy::50");
            assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Deploy::51");
        }

        vm.selectFork(script.optimismForkId());

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[1].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            assertEq(dataFeed, OPTIMISM_WSTETH_STETH_DATAFEED, "test_Deploy::52");
            assertEq(isInverse, OPTIMISM_WSTETH_STETH_DATAFEED_IS_INVERSE, "test_Deploy::53");
            assertEq(heartbeat, OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT, "test_Deploy::54");
            assertEq(AggregatorV3Interface(dataFeed).decimals(), decimals, "test_Deploy::55");

            OraclePool oraclePool = OraclePool(l2Contracts[1].oraclePool);

            assertEq(oraclePool.SENDER(), l2Contracts[1].sender.proxy, "test_Deploy::56");
            assertEq(oraclePool.TOKEN_IN(), OPTIMISM_WETH_TOKEN, "test_Deploy::57");
            assertEq(oraclePool.TOKEN_OUT(), OPTIMISM_WSTETH_TOKEN, "test_Deploy::58");
            assertEq(oraclePool.getOracle(), l2Contracts[1].priceOracle, "test_Deploy::59");
            assertEq(oraclePool.getFee(), OPTIMISM_ORACLE_POOL_FEE, "test_Deploy::60");
            assertEq(oraclePool.owner(), deployer, "test_Deploy::61");

            CustomSender sender = CustomSender(l2Contracts[1].sender.proxy);

            assertEq(sender.WNATIVE(), OPTIMISM_WETH_TOKEN, "test_Deploy::62");
            assertEq(sender.LINK_TOKEN(), OPTIMISM_LINK_TOKEN, "test_Deploy::63");
            assertEq(sender.CCIP_ROUTER(), OPTIMISM_CCIP_ROUTER, "test_Deploy::64");
            assertEq(sender.getOraclePool(), l2Contracts[1].oraclePool, "test_Deploy::65");
            assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::66");
            assertEq(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[1].syncAutomation), true, "test_Deploy::67");
            assertEq(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)),
                l1Contracts.receiver.proxy,
                "test_Deploy::68"
            );
            assertEq(_getProxyAdmin(l2Contracts[1].sender.proxy), l2Contracts[1].sender.proxyAdmin, "test_Deploy::69");
            assertEq(ProxyAdmin(l2Contracts[1].sender.proxyAdmin).owner(), deployer, "test_Deploy::70");
            assertEq(
                _getProxyImplementation(l2Contracts[1].sender.proxy),
                l2Contracts[1].sender.implementation,
                "test_Deploy::71"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[1].syncAutomation);

            assertEq(syncAutomation.SENDER(), l2Contracts[1].sender.proxy, "test_Deploy::72");
            assertEq(syncAutomation.DEST_CHAIN_SELECTOR(), ETHEREUM_CCIP_CHAIN_SELECTOR, "test_Deploy::73");
            assertEq(syncAutomation.WNATIVE(), OPTIMISM_WETH_TOKEN, "test_Deploy::74");
            assertEq(syncAutomation.owner(), deployer, "test_Deploy::75");
            assertEq(syncAutomation.getLastExecution(), block.timestamp, "test_Deploy::76");
            assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Deploy::77");
        }

        vm.selectFork(script.baseForkId());

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[2].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            assertEq(dataFeed, BASE_WSTETH_STETH_DATAFEED, "test_Deploy::78");
            assertEq(isInverse, BASE_WSTETH_STETH_DATAFEED_IS_INVERSE, "test_Deploy::79");
            assertEq(heartbeat, BASE_WSTETH_STETH_DATAFEED_HEARTBEAT, "test_Deploy::80");
            assertEq(AggregatorV3Interface(dataFeed).decimals(), decimals, "test_Deploy::81");

            OraclePool oraclePool = OraclePool(l2Contracts[2].oraclePool);

            assertEq(oraclePool.SENDER(), l2Contracts[2].sender.proxy, "test_Deploy::82");
            assertEq(oraclePool.TOKEN_IN(), BASE_WETH_TOKEN, "test_Deploy::83");
            assertEq(oraclePool.TOKEN_OUT(), BASE_WSTETH_TOKEN, "test_Deploy::84");
            assertEq(oraclePool.getOracle(), l2Contracts[2].priceOracle, "test_Deploy::85");
            assertEq(oraclePool.getFee(), BASE_ORACLE_POOL_FEE, "test_Deploy::86");
            assertEq(oraclePool.owner(), deployer, "test_Deploy::87");

            CustomSender sender = CustomSender(l2Contracts[2].sender.proxy);

            assertEq(sender.WNATIVE(), BASE_WETH_TOKEN, "test_Deploy::88");
            assertEq(sender.LINK_TOKEN(), BASE_LINK_TOKEN, "test_Deploy::89");
            assertEq(sender.CCIP_ROUTER(), BASE_CCIP_ROUTER, "test_Deploy::90");
            assertEq(sender.getOraclePool(), l2Contracts[2].oraclePool, "test_Deploy::91");
            assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::92");
            assertEq(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[2].syncAutomation), true, "test_Deploy::93");
            assertEq(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)),
                l1Contracts.receiver.proxy,
                "test_Deploy::94"
            );
            assertEq(_getProxyAdmin(l2Contracts[2].sender.proxy), l2Contracts[2].sender.proxyAdmin, "test_Deploy::95");
            assertEq(ProxyAdmin(l2Contracts[2].sender.proxyAdmin).owner(), deployer, "test_Deploy::96");
            assertEq(
                _getProxyImplementation(l2Contracts[2].sender.proxy),
                l2Contracts[2].sender.implementation,
                "test_Deploy::97"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[2].syncAutomation);

            assertEq(syncAutomation.SENDER(), l2Contracts[2].sender.proxy, "test_Deploy::98");
            assertEq(syncAutomation.DEST_CHAIN_SELECTOR(), ETHEREUM_CCIP_CHAIN_SELECTOR, "test_Deploy::99");
            assertEq(syncAutomation.WNATIVE(), BASE_WETH_TOKEN, "test_Deploy::100");
            assertEq(syncAutomation.owner(), deployer, "test_Deploy::101");
            assertEq(syncAutomation.getLastExecution(), block.timestamp, "test_Deploy::102");
            assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Deploy::103");
        }
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }

    function _getProxyImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT))));
    }
}
