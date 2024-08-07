// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../script/Eigenpie/EigenpieDeploy.s.sol";

contract EigenpieDeployScriptTest is Test, EigenpieParameters {
    EigenpieDeployScript public script;

    function setUp() public {
        script = new EigenpieDeployScript();
        script.setUp();
    }

    function test_Deploy() public {
        (EigenpieDeployScript.L1Contracts memory l1Contracts, EigenpieDeployScript.L2Contracts[] memory l2Contracts) =
            script.run();

        address deployer = script.deployer();

        vm.selectFork(script.ethereumForkId());

        {
            EigenpieCustomReceiver receiver = EigenpieCustomReceiver(payable(l1Contracts.receiver.proxy));

            assertEq(receiver.EGETH(), ETHEREUM_EGETH_TOKEN, "test_Deploy::1");
            assertEq(receiver.WNATIVE(), ETHEREUM_WETH_TOKEN, "test_Deploy::2");
            assertEq(receiver.CCIP_ROUTER(), ETHEREUM_CCIP_ROUTER, "test_Deploy::3");
            assertEq(receiver.hasRole(receiver.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::4");
            assertEq(receiver.getAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR), l1Contracts.arbitrumAdapter, "test_Deploy::5");
            assertEq(
                receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR),
                abi.encode(l2Contracts[0].sender.proxy),
                "test_Deploy::6"
            );
            assertEq(_getProxyAdmin(l1Contracts.receiver.proxy), l1Contracts.receiver.proxyAdmin, "test_Deploy::7");
            assertEq(ProxyAdmin(l1Contracts.receiver.proxyAdmin).owner(), deployer, "test_Deploy::8");
            assertEq(
                _getProxyImplementation(l1Contracts.receiver.proxy),
                l1Contracts.receiver.implementation,
                "test_Deploy::9"
            );

            CCIPAdapter ccipAdapter = CCIPAdapter(l1Contracts.arbitrumAdapter);

            assertEq(ccipAdapter.LINK_TOKEN(), address(0), "test_Deploy::10");
            assertEq(ccipAdapter.CCIP_ROUTER(), ETHEREUM_CCIP_ROUTER, "test_Deploy::11");
            assertEq(ccipAdapter.L1_TOKEN(), ETHEREUM_EGETH_TOKEN, "test_Deploy::12");
        }

        vm.selectFork(script.arbitrumForkId());

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            assertEq(dataFeed, ARBITRUM_EGETH_ETH_DATAFEED, "test_Deploy::13");
            assertEq(isInverse, ARBITRUM_EGETH_ETH_DATAFEED_IS_INVERSE, "test_Deploy::14");
            assertEq(heartbeat, ARBITRUM_EGETH_ETH_DATAFEED_HEARTBEAT, "test_Deploy::15");
            assertEq(AggregatorV3Interface(dataFeed).decimals(), decimals, "test_Deploy::16");

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            assertEq(oraclePool.SENDER(), l2Contracts[0].sender.proxy, "test_Deploy::17");
            assertEq(oraclePool.TOKEN_IN(), ARBITRUM_WETH_TOKEN, "test_Deploy::18");
            assertEq(oraclePool.TOKEN_OUT(), ARBITRUM_EGETH_TOKEN, "test_Deploy::19");
            assertEq(oraclePool.getOracle(), l2Contracts[0].priceOracle, "test_Deploy::20");
            assertEq(oraclePool.getFee(), ARBITRUM_ORACLE_POOL_FEE, "test_Deploy::21");
            assertEq(oraclePool.owner(), deployer, "test_Deploy::22");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            assertEq(sender.WNATIVE(), ARBITRUM_WETH_TOKEN, "test_Deploy::23");
            assertEq(sender.LINK_TOKEN(), ARBITRUM_LINK_TOKEN, "test_Deploy::24");
            assertEq(sender.CCIP_ROUTER(), ARBITRUM_CCIP_ROUTER, "test_Deploy::25");
            assertEq(sender.getOraclePool(), l2Contracts[0].oraclePool, "test_Deploy::26");
            assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), true, "test_Deploy::27");
            assertEq(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), true, "test_Deploy::28");
            assertEq(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)),
                l1Contracts.receiver.proxy,
                "test_Deploy::29"
            );
            assertEq(_getProxyAdmin(l2Contracts[0].sender.proxy), l2Contracts[0].sender.proxyAdmin, "test_Deploy::30");
            assertEq(ProxyAdmin(l2Contracts[0].sender.proxyAdmin).owner(), deployer, "test_Deploy::31");
            assertEq(
                _getProxyImplementation(l2Contracts[0].sender.proxy),
                l2Contracts[0].sender.implementation,
                "test_Deploy::32"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            assertEq(syncAutomation.SENDER(), l2Contracts[0].sender.proxy, "test_Deploy::33");
            assertEq(syncAutomation.DEST_CHAIN_SELECTOR(), ETHEREUM_CCIP_CHAIN_SELECTOR, "test_Deploy::34");
            assertEq(syncAutomation.WNATIVE(), ARBITRUM_WETH_TOKEN, "test_Deploy::35");
            assertEq(syncAutomation.owner(), deployer, "test_Deploy::36");
            assertEq(syncAutomation.getLastExecution(), block.timestamp, "test_Deploy::37");
            assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Deploy::38");
        }
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }

    function _getProxyImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT))));
    }
}
