// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./LidoParameters.sol";

import "../ScriptHelper.sol";
import "../../contracts/senders/CustomSender.sol";
import "../../contracts/receivers/LidoCustomReceiver.sol";
import "../../contracts/adapters/ArbitrumLegacyAdapterL1toL2.sol";
import "../../contracts/adapters/OptimismLegacyAdapterL1toL2.sol";
import "../../contracts/adapters/BaseLegacyAdapterL1toL2.sol";
import "../../contracts/automations/SyncAutomation.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";

contract LidoDeployScript is ScriptHelper, LidoParameters {
    struct Proxy {
        address proxy;
        address proxyAdmin;
        address implementation;
    }

    struct L1Contracts {
        string chainName;
        Proxy receiver;
        address arbitrumAdapter;
        address optimismAdapter;
        address baseAdapter;
    }

    struct L2Contracts {
        string chainName;
        Proxy sender;
        address priceOracle;
        address oraclePool;
        address syncAutomation;
    }

    uint256 public ethereumForkId;
    uint256 public arbitrumForkId;
    uint256 public optimismForkId;
    uint256 public baseForkId;

    address public deployer;

    function setUp() public {
        ethereumForkId = vm.createFork(vm.rpcUrl("ethereum"));
        arbitrumForkId = vm.createFork(vm.rpcUrl("arbitrum"));
        optimismForkId = vm.createFork(vm.rpcUrl("optimism"));
        baseForkId = vm.createFork(vm.rpcUrl("base"));
    }

    function run() public returns (L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        l1Contracts.chainName = "Ethereum";

        l2Contracts = new L2Contracts[](3);

        L2Contracts memory arbContracts = l2Contracts[0];
        L2Contracts memory optContracts = l2Contracts[1];
        L2Contracts memory baseContracts = l2Contracts[2];

        arbContracts.chainName = "Arbitrum";
        optContracts.chainName = "Optimism";
        baseContracts.chainName = "Base";

        // Deploy contracts on Ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            l1Contracts.receiver.implementation = address(
                new LidoCustomReceiver(
                    ETHEREUM_WSTETH_TOKEN, ETHEREUM_WETH_TOKEN, ETHEREUM_CCIP_ROUTER, address(0xdead)
                )
            );

            l1Contracts.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    l1Contracts.receiver.implementation,
                    deployer,
                    abi.encodeCall(LidoCustomReceiver.initialize, (deployer))
                )
            );

            l1Contracts.receiver.proxyAdmin = _getProxyAdmin(l1Contracts.receiver.proxy);

            l1Contracts.arbitrumAdapter = address(
                new ArbitrumLegacyAdapterL1toL2(
                    ETHEREUM_TO_ARBITRUM_ROUTER, ETHEREUM_WSTETH_TOKEN, l1Contracts.receiver.proxy
                )
            );

            l1Contracts.optimismAdapter = address(
                new OptimismLegacyAdapterL1toL2(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE, l1Contracts.receiver.proxy)
            );

            l1Contracts.baseAdapter =
                address(new BaseLegacyAdapterL1toL2(ETHEREUM_TO_BASE_WSTETH_TOKEN_BRIDGE, l1Contracts.receiver.proxy));

            vm.stopBroadcast();
        }

        // Deploy contracts on Arbitrum
        {
            vm.selectFork(arbitrumForkId);
            vm.startBroadcast(deployerPrivateKey);

            arbContracts.priceOracle = address(
                new PriceOracle(
                    ARBITRUM_WSTETH_STETH_DATAFEED,
                    ARBITRUM_WSTETH_STETH_DATAFEED_IS_INVERSE,
                    ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT,
                    deployer
                )
            );

            arbContracts.oraclePool = address(
                new OraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the impementation and then the proxy, we need to increment the nonce by 2
                    ARBITRUM_WETH_TOKEN,
                    ARBITRUM_WSTETH_TOKEN,
                    arbContracts.priceOracle,
                    ARBITRUM_ORACLE_POOL_FEE,
                    deployer
                )
            );

            arbContracts.sender.implementation = address(
                new CustomSender(
                    ARBITRUM_WETH_TOKEN,
                    ARBITRUM_WETH_TOKEN,
                    ARBITRUM_LINK_TOKEN,
                    ARBITRUM_CCIP_ROUTER,
                    address(0xdead),
                    address(0xdead)
                )
            );

            arbContracts.sender.proxy = address(
                new TransparentUpgradeableProxy(
                    arbContracts.sender.implementation,
                    deployer,
                    abi.encodeCall(CustomSender.initialize, (arbContracts.oraclePool, deployer))
                )
            );

            arbContracts.sender.proxyAdmin = _getProxyAdmin(arbContracts.sender.proxy);

            arbContracts.syncAutomation =
                address(new SyncAutomation(arbContracts.sender.proxy, ETHEREUM_CCIP_CHAIN_SELECTOR, deployer));

            vm.stopBroadcast();
        }

        // Deploy contracts on Optimism
        {
            vm.selectFork(optimismForkId);
            vm.startBroadcast(deployerPrivateKey);

            optContracts.priceOracle = address(
                new PriceOracle(
                    OPTIMISM_WSTETH_STETH_DATAFEED,
                    OPTIMISM_WSTETH_STETH_DATAFEED_IS_INVERSE,
                    OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT,
                    deployer
                )
            );

            optContracts.oraclePool = address(
                new OraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the impementation and then the proxy, we need to increment the nonce by 2
                    OPTIMISM_WETH_TOKEN,
                    OPTIMISM_WSTETH_TOKEN,
                    optContracts.priceOracle,
                    OPTIMISM_ORACLE_POOL_FEE,
                    deployer
                )
            );

            optContracts.sender.implementation = address(
                new CustomSender(
                    OPTIMISM_WETH_TOKEN,
                    OPTIMISM_WETH_TOKEN,
                    OPTIMISM_LINK_TOKEN,
                    OPTIMISM_CCIP_ROUTER,
                    address(0xdead),
                    address(0xdead)
                )
            );

            optContracts.sender.proxy = address(
                new TransparentUpgradeableProxy(
                    optContracts.sender.implementation,
                    deployer,
                    abi.encodeCall(CustomSender.initialize, (optContracts.oraclePool, deployer))
                )
            );

            optContracts.sender.proxyAdmin = _getProxyAdmin(optContracts.sender.proxy);

            optContracts.syncAutomation =
                address(new SyncAutomation(optContracts.sender.proxy, ETHEREUM_CCIP_CHAIN_SELECTOR, deployer));

            vm.stopBroadcast();
        }

        // Deploy contracts on Base
        {
            vm.selectFork(baseForkId);
            vm.startBroadcast(deployerPrivateKey);

            baseContracts.priceOracle = address(
                new PriceOracle(
                    BASE_WSTETH_STETH_DATAFEED,
                    BASE_WSTETH_STETH_DATAFEED_IS_INVERSE,
                    BASE_WSTETH_STETH_DATAFEED_HEARTBEAT,
                    deployer
                )
            );

            baseContracts.oraclePool = address(
                new OraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the impementation and then the proxy, we need to increment the nonce by 2
                    BASE_WETH_TOKEN,
                    BASE_WSTETH_TOKEN,
                    baseContracts.priceOracle,
                    BASE_ORACLE_POOL_FEE,
                    deployer
                )
            );

            baseContracts.sender.implementation = address(
                new CustomSender(
                    BASE_WETH_TOKEN,
                    BASE_WETH_TOKEN,
                    BASE_LINK_TOKEN,
                    BASE_CCIP_ROUTER,
                    address(0xdead),
                    address(0xdead)
                )
            );

            baseContracts.sender.proxy = address(
                new TransparentUpgradeableProxy(
                    baseContracts.sender.implementation,
                    deployer,
                    abi.encodeCall(CustomSender.initialize, (baseContracts.oraclePool, deployer))
                )
            );

            baseContracts.sender.proxyAdmin = _getProxyAdmin(baseContracts.sender.proxy);

            baseContracts.syncAutomation =
                address(new SyncAutomation(baseContracts.sender.proxy, ETHEREUM_CCIP_CHAIN_SELECTOR, deployer));

            vm.stopBroadcast();
        }

        // Set up contracts on ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            LidoCustomReceiver(payable(l1Contracts.receiver.proxy)).setAdapter(
                ARBITRUM_CCIP_CHAIN_SELECTOR, l1Contracts.arbitrumAdapter
            );
            LidoCustomReceiver(payable(l1Contracts.receiver.proxy)).setAdapter(
                OPTIMISM_CCIP_CHAIN_SELECTOR, l1Contracts.optimismAdapter
            );
            LidoCustomReceiver(payable(l1Contracts.receiver.proxy)).setAdapter(
                BASE_CCIP_CHAIN_SELECTOR, l1Contracts.baseAdapter
            );

            LidoCustomReceiver(payable(l1Contracts.receiver.proxy)).setSender(
                ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(arbContracts.sender.proxy)
            );
            LidoCustomReceiver(payable(l1Contracts.receiver.proxy)).setSender(
                OPTIMISM_CCIP_CHAIN_SELECTOR, abi.encode(optContracts.sender.proxy)
            );
            LidoCustomReceiver(payable(l1Contracts.receiver.proxy)).setSender(
                BASE_CCIP_CHAIN_SELECTOR, abi.encode(baseContracts.sender.proxy)
            );

            vm.stopBroadcast();
        }

        // Set up contracts on Arbitrum
        {
            vm.selectFork(arbitrumForkId);
            vm.startBroadcast(deployerPrivateKey);

            CustomSender(arbContracts.sender.proxy).setReceiver(
                ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(l1Contracts.receiver.proxy)
            );

            CustomSender(arbContracts.sender.proxy).grantRole(keccak256("SYNC_ROLE"), arbContracts.syncAutomation);

            vm.stopBroadcast();
        }

        // Set up contracts on Optimism
        {
            vm.selectFork(optimismForkId);
            vm.startBroadcast(deployerPrivateKey);

            CustomSender(optContracts.sender.proxy).setReceiver(
                ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(l1Contracts.receiver.proxy)
            );

            CustomSender(optContracts.sender.proxy).grantRole(keccak256("SYNC_ROLE"), optContracts.syncAutomation);

            vm.stopBroadcast();
        }

        // Set up contracts on Base
        {
            vm.selectFork(baseForkId);
            vm.startBroadcast(deployerPrivateKey);

            CustomSender(baseContracts.sender.proxy).setReceiver(
                ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(l1Contracts.receiver.proxy)
            );

            CustomSender(baseContracts.sender.proxy).grantRole(keccak256("SYNC_ROLE"), baseContracts.syncAutomation);

            vm.stopBroadcast();
        }

        _verifyContracts(l1Contracts, l2Contracts);
    }

    function _verifyContracts(L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) internal {
        vm.selectFork(ethereumForkId);

        {
            LidoCustomReceiver receiver = LidoCustomReceiver(payable(l1Contracts.receiver.proxy));

            require(receiver.WSTETH() == ETHEREUM_WSTETH_TOKEN, "LidoDeployScript::1");
            require(receiver.WNATIVE() == ETHEREUM_WETH_TOKEN, "LidoDeployScript::2");
            require(receiver.CCIP_ROUTER() == ETHEREUM_CCIP_ROUTER, "LidoDeployScript::3");
            require(receiver.hasRole(receiver.DEFAULT_ADMIN_ROLE(), deployer), "LidoDeployScript::4");
            require(receiver.getAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR) == l1Contracts.arbitrumAdapter, "LidoDeployScript::5");
            require(receiver.getAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR) == l1Contracts.optimismAdapter, "LidoDeployScript::6");
            require(receiver.getAdapter(BASE_CCIP_CHAIN_SELECTOR) == l1Contracts.baseAdapter, "LidoDeployScript::7");
            require(
                keccak256(receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[0].sender.proxy)),
                "LidoDeployScript::8"
            );
            require(
                keccak256(receiver.getSender(OPTIMISM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[1].sender.proxy)),
                "LidoDeployScript::9"
            );
            require(
                keccak256(receiver.getSender(BASE_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[2].sender.proxy)),
                "LidoDeployScript::10"
            );
            require(_getProxyAdmin(l1Contracts.receiver.proxy) == l1Contracts.receiver.proxyAdmin, "LidoDeployScript::11");
            require(ProxyAdmin(l1Contracts.receiver.proxyAdmin).owner() == deployer, "LidoDeployScript::12");
            require(
                _getProxyImplementation(l1Contracts.receiver.proxy) == l1Contracts.receiver.implementation,
                "LidoDeployScript::13"
            );

            ArbitrumLegacyAdapterL1toL2 arbAdapter = ArbitrumLegacyAdapterL1toL2(l1Contracts.arbitrumAdapter);

            require(arbAdapter.L1_GATEWAY_ROUTER() == ETHEREUM_TO_ARBITRUM_ROUTER, "LidoDeployScript::14");
            require(arbAdapter.L1_TOKEN() == ETHEREUM_WSTETH_TOKEN, "LidoDeployScript::15");
            require(
                arbAdapter.L1_TOKEN_GATEWAY()
                    == IArbitrumL1GatewayRouter(ETHEREUM_TO_ARBITRUM_ROUTER).l1TokenToGateway(ETHEREUM_WSTETH_TOKEN),
                "LidoDeployScript::16"
            );
            require(arbAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "LidoDeployScript::17");

            OptimismLegacyAdapterL1toL2 optAdapter = OptimismLegacyAdapterL1toL2(l1Contracts.optimismAdapter);

            require(optAdapter.L1_ERC20_BRIDGE() == ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE, "LidoDeployScript::18");
            require(
                optAdapter.L1_TOKEN() == IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).l1Token(),
                "LidoDeployScript::19"
            );
            require(
                optAdapter.L2_TOKEN() == IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).l2Token(),
                "LidoDeployScript::20"
            );
            require(optAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "LidoDeployScript::21");

            BaseLegacyAdapterL1toL2 baseAdapter = BaseLegacyAdapterL1toL2(l1Contracts.baseAdapter);

            require(baseAdapter.L1_ERC20_BRIDGE() == ETHEREUM_TO_BASE_WSTETH_TOKEN_BRIDGE, "LidoDeployScript::22");
            require(baseAdapter.L1_TOKEN() == ETHEREUM_WSTETH_TOKEN, "LidoDeployScript::23");
            require(baseAdapter.L2_TOKEN() == BASE_WSTETH_TOKEN, "LidoDeployScript::24");
            require(baseAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "LidoDeployScript::25");
        }

        vm.selectFork(arbitrumForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            require(dataFeed == ARBITRUM_WSTETH_STETH_DATAFEED, "LidoDeployScript::26");
            require(isInverse == ARBITRUM_WSTETH_STETH_DATAFEED_IS_INVERSE, "LidoDeployScript::27");
            require(heartbeat == ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT, "LidoDeployScript::28");
            require(AggregatorV3Interface(dataFeed).decimals() == decimals, "LidoDeployScript::29");

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[0].sender.proxy, "LidoDeployScript::30");
            require(oraclePool.TOKEN_IN() == ARBITRUM_WETH_TOKEN, "LidoDeployScript::31");
            require(oraclePool.TOKEN_OUT() == ARBITRUM_WSTETH_TOKEN, "LidoDeployScript::32");
            require(oraclePool.getOracle() == l2Contracts[0].priceOracle, "LidoDeployScript::33");
            require(oraclePool.getFee() == ARBITRUM_ORACLE_POOL_FEE, "LidoDeployScript::34");
            require(oraclePool.owner() == deployer, "LidoDeployScript::35");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            require(sender.WNATIVE() == ARBITRUM_WETH_TOKEN, "LidoDeployScript::36");
            require(sender.LINK_TOKEN() == ARBITRUM_LINK_TOKEN, "LidoDeployScript::37");
            require(sender.CCIP_ROUTER() == ARBITRUM_CCIP_ROUTER, "LidoDeployScript::38");
            require(sender.getOraclePool() == l2Contracts[0].oraclePool, "LidoDeployScript::39");
            require(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), "LidoDeployScript::40");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), "LidoDeployScript::41");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "LidoDeployScript::42"
            );
            require(_getProxyAdmin(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.proxyAdmin, "LidoDeployScript::43");
            require(ProxyAdmin(l2Contracts[0].sender.proxyAdmin).owner() == deployer, "LidoDeployScript::44");
            require(
                _getProxyImplementation(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.implementation,
                "LidoDeployScript::45"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[0].sender.proxy, "LidoDeployScript::46");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "LidoDeployScript::47");
            require(syncAutomation.WNATIVE() == ARBITRUM_WETH_TOKEN, "LidoDeployScript::48");
            require(syncAutomation.owner() == deployer, "LidoDeployScript::49");
            require(syncAutomation.getLastExecution() == block.timestamp, "LidoDeployScript::50");
            require(syncAutomation.getDelay() == type(uint48).max, "LidoDeployScript::51");
        }

        vm.selectFork(optimismForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[1].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            require(dataFeed == OPTIMISM_WSTETH_STETH_DATAFEED, "LidoDeployScript::52");
            require(isInverse == OPTIMISM_WSTETH_STETH_DATAFEED_IS_INVERSE, "LidoDeployScript::53");
            require(heartbeat == OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT, "LidoDeployScript::54");
            require(AggregatorV3Interface(dataFeed).decimals() == decimals, "LidoDeployScript::55");

            OraclePool oraclePool = OraclePool(l2Contracts[1].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[1].sender.proxy, "LidoDeployScript::56");
            require(oraclePool.TOKEN_IN() == OPTIMISM_WETH_TOKEN, "LidoDeployScript::57");
            require(oraclePool.TOKEN_OUT() == OPTIMISM_WSTETH_TOKEN, "LidoDeployScript::58");
            require(oraclePool.getOracle() == l2Contracts[1].priceOracle, "LidoDeployScript::59");
            require(oraclePool.getFee() == OPTIMISM_ORACLE_POOL_FEE, "LidoDeployScript::60");
            require(oraclePool.owner() == deployer, "LidoDeployScript::61");

            CustomSender sender = CustomSender(l2Contracts[1].sender.proxy);

            require(sender.WNATIVE() == OPTIMISM_WETH_TOKEN, "LidoDeployScript::62");
            require(sender.LINK_TOKEN() == OPTIMISM_LINK_TOKEN, "LidoDeployScript::63");
            require(sender.CCIP_ROUTER() == OPTIMISM_CCIP_ROUTER, "LidoDeployScript::64");
            require(sender.getOraclePool() == l2Contracts[1].oraclePool, "LidoDeployScript::65");
            require(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), "LidoDeployScript::66");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[1].syncAutomation), "LidoDeployScript::67");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "LidoDeployScript::68"
            );
            require(_getProxyAdmin(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.proxyAdmin, "LidoDeployScript::69");
            require(ProxyAdmin(l2Contracts[1].sender.proxyAdmin).owner() == deployer, "LidoDeployScript::70");
            require(
                _getProxyImplementation(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.implementation,
                "LidoDeployScript::71"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[1].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[1].sender.proxy, "LidoDeployScript::72");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "LidoDeployScript::73");
            require(syncAutomation.WNATIVE() == OPTIMISM_WETH_TOKEN, "LidoDeployScript::74");
            require(syncAutomation.owner() == deployer, "LidoDeployScript::75");
            require(syncAutomation.getLastExecution() == block.timestamp, "LidoDeployScript::76");
            require(syncAutomation.getDelay() == type(uint48).max, "LidoDeployScript::77");
        }

        vm.selectFork(baseForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[2].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            require(dataFeed == BASE_WSTETH_STETH_DATAFEED, "LidoDeployScript::78");
            require(isInverse == BASE_WSTETH_STETH_DATAFEED_IS_INVERSE, "LidoDeployScript::79");
            require(heartbeat == BASE_WSTETH_STETH_DATAFEED_HEARTBEAT, "LidoDeployScript::80");
            require(AggregatorV3Interface(dataFeed).decimals() == decimals, "LidoDeployScript::81");

            OraclePool oraclePool = OraclePool(l2Contracts[2].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[2].sender.proxy, "LidoDeployScript::82");
            require(oraclePool.TOKEN_IN() == BASE_WETH_TOKEN, "LidoDeployScript::83");
            require(oraclePool.TOKEN_OUT() == BASE_WSTETH_TOKEN, "LidoDeployScript::84");
            require(oraclePool.getOracle() == l2Contracts[2].priceOracle, "LidoDeployScript::85");
            require(oraclePool.getFee() == BASE_ORACLE_POOL_FEE, "LidoDeployScript::86");
            require(oraclePool.owner() == deployer, "LidoDeployScript::87");

            CustomSender sender = CustomSender(l2Contracts[2].sender.proxy);

            require(sender.WNATIVE() == BASE_WETH_TOKEN, "LidoDeployScript::88");
            require(sender.LINK_TOKEN() == BASE_LINK_TOKEN, "LidoDeployScript::89");
            require(sender.CCIP_ROUTER() == BASE_CCIP_ROUTER, "LidoDeployScript::90");
            require(sender.getOraclePool() == l2Contracts[2].oraclePool, "LidoDeployScript::91");
            require(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), "LidoDeployScript::92");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[2].syncAutomation), "LidoDeployScript::93");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "LidoDeployScript::94"
            );
            require(_getProxyAdmin(l2Contracts[2].sender.proxy) == l2Contracts[2].sender.proxyAdmin, "LidoDeployScript::95");
            require(ProxyAdmin(l2Contracts[2].sender.proxyAdmin).owner() == deployer, "LidoDeployScript::96");
            require(
                _getProxyImplementation(l2Contracts[2].sender.proxy) == l2Contracts[2].sender.implementation,
                "LidoDeployScript::97"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[2].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[2].sender.proxy, "LidoDeployScript::98");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "LidoDeployScript::99");
            require(syncAutomation.WNATIVE() == BASE_WETH_TOKEN, "LidoDeployScript::100");
            require(syncAutomation.owner() == deployer, "LidoDeployScript::101");
            require(syncAutomation.getLastExecution() == block.timestamp, "LidoDeployScript::102");
            require(syncAutomation.getDelay() == type(uint48).max, "LidoDeployScript::103");
        }
    }
}
