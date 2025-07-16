// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../contracts/adapters/ArbitrumLegacyAdapterL1toL2.sol";
import "../../contracts/adapters/BaseLegacyAdapterL1toL2.sol";
import "../../contracts/adapters/LineaAdapterL1toL2.sol";
import "../../contracts/adapters/OptimismLegacyAdapterL1toL2.sol";
import "../../contracts/automations/SyncAutomation.sol";
import "../../contracts/receivers/LidoCustomReceiver.sol";
import "../../contracts/senders/CustomSender.sol";
import "../../contracts/utils/PausableImmutableOraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";
import "../ScriptHelper.sol";
import "./LidoParameters.sol";

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
        address lineaAdapter;
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
    uint256 public lineaForkId;

    address public deployer;

    function setUp() public {
        ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"));
        arbitrumForkId = vm.createFork(vm.rpcUrl("arbitrum"));
        optimismForkId = vm.createFork(vm.rpcUrl("optimism"));
        baseForkId = vm.createFork(vm.rpcUrl("base"));
        lineaForkId = vm.createFork(vm.rpcUrl("linea"));
    }

    function run() public returns (L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) {
        uint256 deployerPrivateKey = vm.envUint("LIDO_DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        l1Contracts.chainName = "Ethereum";

        l2Contracts = new L2Contracts[](4);

        L2Contracts memory arbContracts = l2Contracts[0];
        L2Contracts memory optContracts = l2Contracts[1];
        L2Contracts memory baseContracts = l2Contracts[2];
        L2Contracts memory lineaContracts = l2Contracts[3];

        arbContracts.chainName = "Arbitrum";
        optContracts.chainName = "Optimism";
        baseContracts.chainName = "Base";
        lineaContracts.chainName = "Linea";

        // Deploy contracts on Ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            l1Contracts.receiver.implementation = address(
                new LidoCustomReceiver(ETHEREUM_WSTETH_TOKEN, ETHEREUM_WETH_TOKEN, ETHEREUM_CCIP_ROUTER, DEAD_ADDRESS)
            );

            l1Contracts.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    l1Contracts.receiver.implementation,
                    ETHEREUM_OWNER == address(0) ? deployer : ETHEREUM_OWNER,
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

            l1Contracts.lineaAdapter = address(
                new LineaAdapterL1toL2(
                    ETHEREUM_TO_LINEA_WSTETH_TOKEN_BRIDGE, ETHEREUM_WSTETH_TOKEN, l1Contracts.receiver.proxy
                )
            );

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
                    ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT
                )
            );

            arbContracts.oraclePool = address(
                new PausableImmutableOraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the implementation and then the proxy, we need to increment the nonce by 2
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
                    DEAD_ADDRESS,
                    DEAD_ADDRESS
                )
            );

            arbContracts.sender.proxy = address(
                new TransparentUpgradeableProxy(
                    arbContracts.sender.implementation,
                    ARBITRUM_OWNER == address(0) ? deployer : ARBITRUM_OWNER,
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
                    OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT
                )
            );

            optContracts.oraclePool = address(
                new PausableImmutableOraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the implementation and then the proxy, we need to increment the nonce by 2
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
                    DEAD_ADDRESS,
                    DEAD_ADDRESS
                )
            );

            optContracts.sender.proxy = address(
                new TransparentUpgradeableProxy(
                    optContracts.sender.implementation,
                    OPTIMISM_OWNER == address(0) ? deployer : OPTIMISM_OWNER,
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
                    BASE_WSTETH_STETH_DATAFEED_HEARTBEAT
                )
            );

            baseContracts.oraclePool = address(
                new PausableImmutableOraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the implementation and then the proxy, we need to increment the nonce by 2
                    BASE_WETH_TOKEN,
                    BASE_WSTETH_TOKEN,
                    baseContracts.priceOracle,
                    BASE_ORACLE_POOL_FEE,
                    deployer
                )
            );

            baseContracts.sender.implementation = address(
                new CustomSender(
                    BASE_WETH_TOKEN, BASE_WETH_TOKEN, BASE_LINK_TOKEN, BASE_CCIP_ROUTER, DEAD_ADDRESS, DEAD_ADDRESS
                )
            );

            baseContracts.sender.proxy = address(
                new TransparentUpgradeableProxy(
                    baseContracts.sender.implementation,
                    BASE_OWNER == address(0) ? deployer : BASE_OWNER,
                    abi.encodeCall(CustomSender.initialize, (baseContracts.oraclePool, deployer))
                )
            );

            baseContracts.sender.proxyAdmin = _getProxyAdmin(baseContracts.sender.proxy);

            baseContracts.syncAutomation =
                address(new SyncAutomation(baseContracts.sender.proxy, ETHEREUM_CCIP_CHAIN_SELECTOR, deployer));

            vm.stopBroadcast();
        }

        // Deploy contracts on Linea
        {
            vm.selectFork(lineaForkId);
            vm.startBroadcast(deployerPrivateKey);

            lineaContracts.priceOracle = address(
                new PriceOracle(
                    LINEA_WSTETH_STETH_DATAFEED,
                    LINEA_WSTETH_STETH_DATAFEED_IS_INVERSE,
                    LINEA_WSTETH_STETH_DATAFEED_HEARTBEAT
                )
            );

            lineaContracts.oraclePool = address(
                new PausableImmutableOraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the implementation and then the proxy, we need to increment the nonce by 2
                    LINEA_WETH_TOKEN,
                    LINEA_WSTETH_TOKEN,
                    lineaContracts.priceOracle,
                    LINEA_ORACLE_POOL_FEE,
                    deployer
                )
            );

            lineaContracts.sender.implementation = address(
                new CustomSender(
                    LINEA_WETH_TOKEN, LINEA_WETH_TOKEN, LINEA_LINK_TOKEN, LINEA_CCIP_ROUTER, DEAD_ADDRESS, DEAD_ADDRESS
                )
            );

            lineaContracts.sender.proxy = address(
                new TransparentUpgradeableProxy(
                    lineaContracts.sender.implementation,
                    LINEA_OWNER == address(0) ? deployer : LINEA_OWNER,
                    abi.encodeCall(CustomSender.initialize, (lineaContracts.oraclePool, deployer))
                )
            );

            lineaContracts.sender.proxyAdmin = _getProxyAdmin(lineaContracts.sender.proxy);

            lineaContracts.syncAutomation =
                address(new SyncAutomation(lineaContracts.sender.proxy, ETHEREUM_CCIP_CHAIN_SELECTOR, deployer));

            vm.stopBroadcast();
        }

        // Set up contracts on Ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            LidoCustomReceiver receiver = LidoCustomReceiver(payable(l1Contracts.receiver.proxy));

            receiver.setAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR, l1Contracts.arbitrumAdapter);
            receiver.setAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR, l1Contracts.optimismAdapter);
            receiver.setAdapter(BASE_CCIP_CHAIN_SELECTOR, l1Contracts.baseAdapter);
            receiver.setAdapter(LINEA_CCIP_CHAIN_SELECTOR, l1Contracts.lineaAdapter);

            receiver.setSender(ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(arbContracts.sender.proxy));
            receiver.setSender(OPTIMISM_CCIP_CHAIN_SELECTOR, abi.encode(optContracts.sender.proxy));
            receiver.setSender(BASE_CCIP_CHAIN_SELECTOR, abi.encode(baseContracts.sender.proxy));
            receiver.setSender(LINEA_CCIP_CHAIN_SELECTOR, abi.encode(lineaContracts.sender.proxy));

            if (ETHEREUM_OWNER != address(0)) {
                receiver.grantRole(receiver.DEFAULT_ADMIN_ROLE(), ETHEREUM_OWNER);
                receiver.renounceRole(receiver.DEFAULT_ADMIN_ROLE(), deployer);
            }

            vm.stopBroadcast();
        }

        // Set up contracts on Arbitrum
        {
            vm.selectFork(arbitrumForkId);
            vm.startBroadcast(deployerPrivateKey);

            CustomSender sender = CustomSender(arbContracts.sender.proxy);
            ISyncAutomation syncAutomation = ISyncAutomation(arbContracts.syncAutomation);

            sender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(l1Contracts.receiver.proxy));

            sender.grantRole(sender.SYNC_ROLE(), address(syncAutomation));

            syncAutomation.setFeeOtoD(
                FeeCodec.encodeCCIP(
                    ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                )
            );
            syncAutomation.setFeeDtoO(
                FeeCodec.encodeArbitrumL1toL2(
                    ARBITRUM_ORIGIN_MAX_SUBMISSION_COST, ARBITRUM_ORIGIN_MAX_GAS, ARBITRUM_ORIGIN_GAS_PRICE_BID
                )
            );

            syncAutomation.setAmounts(ARBITRUM_MIN_SYNC_AMOUNT, ARBITRUM_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(ARBITRUM_MIN_SYNC_DELAY);

            if (ARBITRUM_OWNER != address(0)) {
                PausableImmutableOraclePool(arbContracts.oraclePool).transferOwnership(ARBITRUM_OWNER);
                Ownable(address(syncAutomation)).transferOwnership(ARBITRUM_OWNER);

                sender.grantRole(sender.DEFAULT_ADMIN_ROLE(), ARBITRUM_OWNER);
                sender.renounceRole(sender.DEFAULT_ADMIN_ROLE(), deployer);
            }

            vm.stopBroadcast();
        }

        // Set up contracts on Optimism
        {
            vm.selectFork(optimismForkId);
            vm.startBroadcast(deployerPrivateKey);

            CustomSender sender = CustomSender(optContracts.sender.proxy);
            ISyncAutomation syncAutomation = ISyncAutomation(optContracts.syncAutomation);

            sender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(l1Contracts.receiver.proxy));

            sender.grantRole(sender.SYNC_ROLE(), address(syncAutomation));

            syncAutomation.setFeeOtoD(
                FeeCodec.encodeCCIP(
                    ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                )
            );
            syncAutomation.setFeeDtoO(FeeCodec.encodeOptimismL1toL2(OPTIMISM_ORIGIN_L2_GAS));

            syncAutomation.setAmounts(OPTIMISM_MIN_SYNC_AMOUNT, OPTIMISM_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(OPTIMISM_MIN_SYNC_DELAY);

            if (OPTIMISM_OWNER != address(0)) {
                PausableImmutableOraclePool(optContracts.oraclePool).transferOwnership(OPTIMISM_OWNER);
                Ownable(address(syncAutomation)).transferOwnership(OPTIMISM_OWNER);

                sender.grantRole(sender.DEFAULT_ADMIN_ROLE(), OPTIMISM_OWNER);
                sender.renounceRole(sender.DEFAULT_ADMIN_ROLE(), deployer);
            }

            vm.stopBroadcast();
        }

        // Set up contracts on Base
        {
            vm.selectFork(baseForkId);
            vm.startBroadcast(deployerPrivateKey);

            CustomSender sender = CustomSender(baseContracts.sender.proxy);
            ISyncAutomation syncAutomation = ISyncAutomation(baseContracts.syncAutomation);

            sender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(l1Contracts.receiver.proxy));

            sender.grantRole(sender.SYNC_ROLE(), baseContracts.syncAutomation);

            syncAutomation.setFeeOtoD(
                FeeCodec.encodeCCIP(
                    ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                )
            );
            syncAutomation.setFeeDtoO(FeeCodec.encodeBaseL1toL2(BASE_ORIGIN_L2_GAS));
            syncAutomation.setAmounts(BASE_MIN_SYNC_AMOUNT, BASE_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(BASE_MIN_SYNC_DELAY);

            if (BASE_OWNER != address(0)) {
                PausableImmutableOraclePool(baseContracts.oraclePool).transferOwnership(BASE_OWNER);
                Ownable(address(syncAutomation)).transferOwnership(BASE_OWNER);

                sender.grantRole(sender.DEFAULT_ADMIN_ROLE(), BASE_OWNER);
                sender.renounceRole(sender.DEFAULT_ADMIN_ROLE(), deployer);
            }

            vm.stopBroadcast();
        }

        // Set up contracts on Linea
        {
            vm.selectFork(lineaForkId);
            vm.startBroadcast(deployerPrivateKey);

            CustomSender sender = CustomSender(lineaContracts.sender.proxy);
            ISyncAutomation syncAutomation = ISyncAutomation(lineaContracts.syncAutomation);

            sender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(l1Contracts.receiver.proxy));

            sender.grantRole(sender.SYNC_ROLE(), address(syncAutomation));

            syncAutomation.setFeeOtoD(
                FeeCodec.encodeCCIP(
                    ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                )
            );
            syncAutomation.setFeeDtoO(FeeCodec.encodeLineaL1toL2());
            syncAutomation.setAmounts(LINEA_MIN_SYNC_AMOUNT, LINEA_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(LINEA_MIN_SYNC_DELAY);

            if (LINEA_OWNER != address(0)) {
                PausableImmutableOraclePool(lineaContracts.oraclePool).transferOwnership(LINEA_OWNER);
                Ownable(address(syncAutomation)).transferOwnership(LINEA_OWNER);

                sender.grantRole(sender.DEFAULT_ADMIN_ROLE(), LINEA_OWNER);
                sender.renounceRole(sender.DEFAULT_ADMIN_ROLE(), deployer);
            }

            vm.stopBroadcast();
        }

        _verifyDeployments(l1Contracts, l2Contracts);
    }

    function _verifyDeployments(L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) internal {
        vm.selectFork(ethereumForkId);

        {
            LidoCustomReceiver receiver = LidoCustomReceiver(payable(l1Contracts.receiver.proxy));

            require(receiver.WSTETH() == ETHEREUM_WSTETH_TOKEN, "_verifyDeployments::1");
            require(receiver.WNATIVE() == ETHEREUM_WETH_TOKEN, "_verifyDeployments::2");
            require(receiver.CCIP_ROUTER() == ETHEREUM_CCIP_ROUTER, "_verifyDeployments::3");
            _checkRole(
                address(receiver), receiver.DEFAULT_ADMIN_ROLE(), deployer, ETHEREUM_OWNER, "_verifyDeployments::4"
            );
            require(
                receiver.getAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR) == l1Contracts.arbitrumAdapter,
                "_verifyDeployments::5"
            );
            require(
                receiver.getAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR) == l1Contracts.optimismAdapter,
                "_verifyDeployments::6"
            );
            require(receiver.getAdapter(BASE_CCIP_CHAIN_SELECTOR) == l1Contracts.baseAdapter, "_verifyDeployments::7");
            require(receiver.getAdapter(LINEA_CCIP_CHAIN_SELECTOR) == l1Contracts.lineaAdapter, "_verifyDeployments::8");
            require(
                keccak256(receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[0].sender.proxy)),
                "_verifyDeployments::9"
            );
            require(
                keccak256(receiver.getSender(OPTIMISM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[1].sender.proxy)),
                "_verifyDeployments::10"
            );
            require(
                keccak256(receiver.getSender(BASE_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[2].sender.proxy)),
                "_verifyDeployments::11"
            );
            require(
                keccak256(receiver.getSender(LINEA_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[3].sender.proxy)),
                "_verifyDeployments::12"
            );
            require(
                _getProxyAdmin(l1Contracts.receiver.proxy) == l1Contracts.receiver.proxyAdmin, "_verifyDeployments::13"
            );
            _checkOwner(l1Contracts.receiver.proxyAdmin, deployer, ETHEREUM_OWNER, "_verifyDeployments::14");
            require(
                _getProxyImplementation(l1Contracts.receiver.proxy) == l1Contracts.receiver.implementation,
                "_verifyDeployments::15"
            );

            ArbitrumLegacyAdapterL1toL2 arbAdapter = ArbitrumLegacyAdapterL1toL2(l1Contracts.arbitrumAdapter);

            require(arbAdapter.L1_GATEWAY_ROUTER() == ETHEREUM_TO_ARBITRUM_ROUTER, "_verifyDeployments::16");
            require(arbAdapter.L1_TOKEN() == ETHEREUM_WSTETH_TOKEN, "_verifyDeployments::17");
            require(
                arbAdapter.L1_TOKEN_GATEWAY()
                    == IArbitrumL1GatewayRouter(ETHEREUM_TO_ARBITRUM_ROUTER).l1TokenToGateway(ETHEREUM_WSTETH_TOKEN),
                "_verifyDeployments::18"
            );
            require(arbAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "_verifyDeployments::19");

            OptimismLegacyAdapterL1toL2 optAdapter = OptimismLegacyAdapterL1toL2(l1Contracts.optimismAdapter);

            require(optAdapter.L1_ERC20_BRIDGE() == ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE, "_verifyDeployments::20");
            require(
                optAdapter.L1_TOKEN()
                    == IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).L1_TOKEN_NON_REBASABLE(),
                "_verifyDeployments::21"
            );
            require(
                optAdapter.L2_TOKEN()
                    == IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).L2_TOKEN_NON_REBASABLE(),
                "_verifyDeployments::22"
            );
            require(optAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "_verifyDeployments::23");

            BaseLegacyAdapterL1toL2 baseAdapter = BaseLegacyAdapterL1toL2(l1Contracts.baseAdapter);

            require(baseAdapter.L1_ERC20_BRIDGE() == ETHEREUM_TO_BASE_WSTETH_TOKEN_BRIDGE, "_verifyDeployments::24");
            require(baseAdapter.L1_TOKEN() == ETHEREUM_WSTETH_TOKEN, "_verifyDeployments::25");
            require(baseAdapter.L2_TOKEN() == BASE_WSTETH_TOKEN, "_verifyDeployments::26");
            require(baseAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "_verifyDeployments::27");

            LineaAdapterL1toL2 lineaAdapter = LineaAdapterL1toL2(l1Contracts.lineaAdapter);

            require(lineaAdapter.TOKEN_BRIDGE() == ETHEREUM_TO_LINEA_WSTETH_TOKEN_BRIDGE, "_verifyDeployments::28");
            require(lineaAdapter.TOKEN() == ETHEREUM_WSTETH_TOKEN, "_verifyDeployments::29");
        }

        vm.selectFork(arbitrumForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            require(priceOracle.AGGREGATOR() == ARBITRUM_WSTETH_STETH_DATAFEED, "_verifyDeployments::30");
            require(priceOracle.IS_INVERSE() == ARBITRUM_WSTETH_STETH_DATAFEED_IS_INVERSE, "_verifyDeployments::31");
            require(priceOracle.HEARTBEAT() == ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT, "_verifyDeployments::32");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(ARBITRUM_WSTETH_STETH_DATAFEED).decimals(),
                "_verifyDeployments::33"
            );

            PausableImmutableOraclePool oraclePool = PausableImmutableOraclePool(l2Contracts[0].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::34");
            require(oraclePool.TOKEN_IN() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::35");
            require(oraclePool.TOKEN_OUT() == ARBITRUM_WSTETH_TOKEN, "_verifyDeployments::36");
            require(oraclePool.getOracle() == l2Contracts[0].priceOracle, "_verifyDeployments::37");
            require(oraclePool.getFee() == ARBITRUM_ORACLE_POOL_FEE, "_verifyDeployments::38");
            _checkOwner(address(oraclePool), deployer, ARBITRUM_OWNER, "_verifyDeployments::39");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            require(sender.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::40");
            require(sender.LINK_TOKEN() == ARBITRUM_LINK_TOKEN, "_verifyDeployments::41");
            require(sender.CCIP_ROUTER() == ARBITRUM_CCIP_ROUTER, "_verifyDeployments::42");
            require(sender.getOraclePool() == l2Contracts[0].oraclePool, "_verifyDeployments::43");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, ARBITRUM_OWNER, "_verifyDeployments::44");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), "_verifyDeployments::45");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::46"
            );
            require(
                _getProxyAdmin(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.proxyAdmin,
                "_verifyDeployments::47"
            );
            _checkOwner(l2Contracts[0].sender.proxyAdmin, deployer, ARBITRUM_OWNER, "_verifyDeployments::48");
            require(
                _getProxyImplementation(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.implementation,
                "_verifyDeployments::49"
            );

            ISyncAutomation syncAutomation = ISyncAutomation(l2Contracts[0].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::50");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::51");
            require(syncAutomation.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::52");
            _checkOwner(address(syncAutomation), deployer, ARBITRUM_OWNER, "_verifyDeployments::53");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::54");
            require(syncAutomation.getDelay() == ARBITRUM_MIN_SYNC_DELAY, "_verifyDeployments::55");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::56"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO())
                    == keccak256(
                        FeeCodec.encodeArbitrumL1toL2(
                            ARBITRUM_ORIGIN_MAX_SUBMISSION_COST, ARBITRUM_ORIGIN_MAX_GAS, ARBITRUM_ORIGIN_GAS_PRICE_BID
                        )
                    ),
                "_verifyDeployments::57"
            );
            (uint256 minSyncAmount, uint256 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == ARBITRUM_MIN_SYNC_AMOUNT, "_verifyDeployments::58");
            require(maxSyncAmount == ARBITRUM_MAX_SYNC_AMOUNT, "_verifyDeployments::59");
        }

        vm.selectFork(optimismForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[1].priceOracle);

            require(priceOracle.AGGREGATOR() == OPTIMISM_WSTETH_STETH_DATAFEED, "_verifyDeployments::60");
            require(priceOracle.IS_INVERSE() == OPTIMISM_WSTETH_STETH_DATAFEED_IS_INVERSE, "_verifyDeployments::61");
            require(priceOracle.HEARTBEAT() == OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT, "_verifyDeployments::62");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(OPTIMISM_WSTETH_STETH_DATAFEED).decimals(),
                "_verifyDeployments::63"
            );

            PausableImmutableOraclePool oraclePool = PausableImmutableOraclePool(l2Contracts[1].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[1].sender.proxy, "_verifyDeployments::64");
            require(oraclePool.TOKEN_IN() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::65");
            require(oraclePool.TOKEN_OUT() == OPTIMISM_WSTETH_TOKEN, "_verifyDeployments::66");
            require(oraclePool.getOracle() == l2Contracts[1].priceOracle, "_verifyDeployments::67");
            require(oraclePool.getFee() == OPTIMISM_ORACLE_POOL_FEE, "_verifyDeployments::68");
            _checkOwner(address(oraclePool), deployer, OPTIMISM_OWNER, "_verifyDeployments::69");

            CustomSender sender = CustomSender(l2Contracts[1].sender.proxy);

            require(sender.WNATIVE() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::70");
            require(sender.LINK_TOKEN() == OPTIMISM_LINK_TOKEN, "_verifyDeployments::71");
            require(sender.CCIP_ROUTER() == OPTIMISM_CCIP_ROUTER, "_verifyDeployments::72");
            require(sender.getOraclePool() == l2Contracts[1].oraclePool, "_verifyDeployments::73");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, OPTIMISM_OWNER, "_verifyDeployments::74");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[1].syncAutomation), "_verifyDeployments::75");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::76"
            );
            require(
                _getProxyAdmin(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.proxyAdmin,
                "_verifyDeployments::77"
            );
            _checkOwner(l2Contracts[1].sender.proxyAdmin, deployer, OPTIMISM_OWNER, "_verifyDeployments::78");
            require(
                _getProxyImplementation(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.implementation,
                "_verifyDeployments::79"
            );

            ISyncAutomation syncAutomation = ISyncAutomation(l2Contracts[1].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[1].sender.proxy, "_verifyDeployments::80");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::81");
            require(syncAutomation.WNATIVE() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::82");
            _checkOwner(address(syncAutomation), deployer, OPTIMISM_OWNER, "_verifyDeployments::83");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::84");
            require(syncAutomation.getDelay() == OPTIMISM_MIN_SYNC_DELAY, "_verifyDeployments::85");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::86"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO())
                    == keccak256(FeeCodec.encodeOptimismL1toL2(OPTIMISM_ORIGIN_L2_GAS)),
                "_verifyDeployments::87"
            );
            (uint256 minSyncAmount, uint256 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == OPTIMISM_MIN_SYNC_AMOUNT, "_verifyDeployments::88");
            require(maxSyncAmount == OPTIMISM_MAX_SYNC_AMOUNT, "_verifyDeployments::89");
        }

        vm.selectFork(baseForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[2].priceOracle);

            require(priceOracle.AGGREGATOR() == BASE_WSTETH_STETH_DATAFEED, "_verifyDeployments::90");
            require(priceOracle.IS_INVERSE() == BASE_WSTETH_STETH_DATAFEED_IS_INVERSE, "_verifyDeployments::91");
            require(priceOracle.HEARTBEAT() == BASE_WSTETH_STETH_DATAFEED_HEARTBEAT, "_verifyDeployments::92");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(BASE_WSTETH_STETH_DATAFEED).decimals(),
                "_verifyDeployments::93"
            );

            PausableImmutableOraclePool oraclePool = PausableImmutableOraclePool(l2Contracts[2].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[2].sender.proxy, "_verifyDeployments::94");
            require(oraclePool.TOKEN_IN() == BASE_WETH_TOKEN, "_verifyDeployments::95");
            require(oraclePool.TOKEN_OUT() == BASE_WSTETH_TOKEN, "_verifyDeployments::96");
            require(oraclePool.getOracle() == l2Contracts[2].priceOracle, "_verifyDeployments::97");
            require(oraclePool.getFee() == BASE_ORACLE_POOL_FEE, "_verifyDeployments::98");
            _checkOwner(address(oraclePool), deployer, BASE_OWNER, "_verifyDeployments::99");

            CustomSender sender = CustomSender(l2Contracts[2].sender.proxy);

            require(sender.WNATIVE() == BASE_WETH_TOKEN, "_verifyDeployments::100");
            require(sender.LINK_TOKEN() == BASE_LINK_TOKEN, "_verifyDeployments::101");
            require(sender.CCIP_ROUTER() == BASE_CCIP_ROUTER, "_verifyDeployments::102");
            require(sender.getOraclePool() == l2Contracts[2].oraclePool, "_verifyDeployments::103");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, BASE_OWNER, "_verifyDeployments::104");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[2].syncAutomation), "_verifyDeployments::105");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::106"
            );
            require(
                _getProxyAdmin(l2Contracts[2].sender.proxy) == l2Contracts[2].sender.proxyAdmin,
                "_verifyDeployments::107"
            );
            _checkOwner(l2Contracts[2].sender.proxyAdmin, deployer, BASE_OWNER, "_verifyDeployments::108");
            require(
                _getProxyImplementation(l2Contracts[2].sender.proxy) == l2Contracts[2].sender.implementation,
                "_verifyDeployments::109"
            );

            ISyncAutomation syncAutomation = ISyncAutomation(l2Contracts[2].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[2].sender.proxy, "_verifyDeployments::110");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::111");
            require(syncAutomation.WNATIVE() == BASE_WETH_TOKEN, "_verifyDeployments::112");
            _checkOwner(address(syncAutomation), deployer, BASE_OWNER, "_verifyDeployments::113");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::114");
            require(syncAutomation.getDelay() == BASE_MIN_SYNC_DELAY, "_verifyDeployments::115");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::116"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO()) == keccak256(FeeCodec.encodeBaseL1toL2(BASE_ORIGIN_L2_GAS)),
                "_verifyDeployments::117"
            );
            (uint256 minSyncAmount, uint256 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == BASE_MIN_SYNC_AMOUNT, "_verifyDeployments::118");
            require(maxSyncAmount == BASE_MAX_SYNC_AMOUNT, "_verifyDeployments::119");
        }

        vm.selectFork(lineaForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[3].priceOracle);

            require(priceOracle.AGGREGATOR() == LINEA_WSTETH_STETH_DATAFEED, "_verifyDeployments::120");
            require(priceOracle.IS_INVERSE() == LINEA_WSTETH_STETH_DATAFEED_IS_INVERSE, "_verifyDeployments::121");
            require(priceOracle.HEARTBEAT() == LINEA_WSTETH_STETH_DATAFEED_HEARTBEAT, "_verifyDeployments::122");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(LINEA_WSTETH_STETH_DATAFEED).decimals(),
                "_verifyDeployments::123"
            );

            PausableImmutableOraclePool oraclePool = PausableImmutableOraclePool(l2Contracts[3].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[3].sender.proxy, "_verifyDeployments::124");
            require(oraclePool.TOKEN_IN() == LINEA_WETH_TOKEN, "_verifyDeployments::125");
            require(oraclePool.TOKEN_OUT() == LINEA_WSTETH_TOKEN, "_verifyDeployments::126");
            require(oraclePool.getOracle() == l2Contracts[3].priceOracle, "_verifyDeployments::127");
            require(oraclePool.getFee() == LINEA_ORACLE_POOL_FEE, "_verifyDeployments::128");
            _checkOwner(address(oraclePool), deployer, LINEA_OWNER, "_verifyDeployments::129");

            CustomSender sender = CustomSender(l2Contracts[3].sender.proxy);

            require(sender.WNATIVE() == LINEA_WETH_TOKEN, "_verifyDeployments::130");
            require(sender.LINK_TOKEN() == LINEA_LINK_TOKEN, "_verifyDeployments::131");
            require(sender.CCIP_ROUTER() == LINEA_CCIP_ROUTER, "_verifyDeployments::132");
            require(sender.getOraclePool() == l2Contracts[3].oraclePool, "_verifyDeployments::133");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, LINEA_OWNER, "_verifyDeployments::134");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[3].syncAutomation), "_verifyDeployments::135");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::136"
            );
            require(
                _getProxyAdmin(l2Contracts[3].sender.proxy) == l2Contracts[3].sender.proxyAdmin,
                "_verifyDeployments::137"
            );
            _checkOwner(l2Contracts[3].sender.proxyAdmin, deployer, LINEA_OWNER, "_verifyDeployments::138");
            require(
                _getProxyImplementation(l2Contracts[3].sender.proxy) == l2Contracts[3].sender.implementation,
                "_verifyDeployments::139"
            );

            ISyncAutomation syncAutomation = ISyncAutomation(l2Contracts[3].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[3].sender.proxy, "_verifyDeployments::140");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::141");
            require(syncAutomation.WNATIVE() == LINEA_WETH_TOKEN, "_verifyDeployments::142");
            _checkOwner(address(syncAutomation), deployer, LINEA_OWNER, "_verifyDeployments::143");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::144");
            require(syncAutomation.getDelay() == LINEA_MIN_SYNC_DELAY, "_verifyDeployments::145");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::146"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO()) == keccak256(FeeCodec.encodeLineaL1toL2()),
                "_verifyDeployments::147"
            );
            (uint256 minSyncAmount, uint256 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == LINEA_MIN_SYNC_AMOUNT, "_verifyDeployments::148");
            require(maxSyncAmount == LINEA_MAX_SYNC_AMOUNT, "_verifyDeployments::149");
        }
    }
}
