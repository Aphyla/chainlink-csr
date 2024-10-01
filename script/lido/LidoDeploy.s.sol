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
import "../../contracts/utils/PausableImmutableOraclePool.sol";
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
        ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"));
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

        // Set up contracts on Ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            LidoCustomReceiver receiver = LidoCustomReceiver(payable(l1Contracts.receiver.proxy));

            receiver.setAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR, l1Contracts.arbitrumAdapter);
            receiver.setAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR, l1Contracts.optimismAdapter);
            receiver.setAdapter(BASE_CCIP_CHAIN_SELECTOR, l1Contracts.baseAdapter);

            receiver.setSender(ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(arbContracts.sender.proxy));
            receiver.setSender(OPTIMISM_CCIP_CHAIN_SELECTOR, abi.encode(optContracts.sender.proxy));
            receiver.setSender(BASE_CCIP_CHAIN_SELECTOR, abi.encode(baseContracts.sender.proxy));

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
            SyncAutomation syncAutomation = SyncAutomation(arbContracts.syncAutomation);

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
                syncAutomation.transferOwnership(ARBITRUM_OWNER);

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
            SyncAutomation syncAutomation = SyncAutomation(optContracts.syncAutomation);

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
                syncAutomation.transferOwnership(OPTIMISM_OWNER);

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
            SyncAutomation syncAutomation = SyncAutomation(baseContracts.syncAutomation);

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
                syncAutomation.transferOwnership(BASE_OWNER);

                sender.grantRole(sender.DEFAULT_ADMIN_ROLE(), BASE_OWNER);
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
            require(
                keccak256(receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[0].sender.proxy)),
                "_verifyDeployments::8"
            );
            require(
                keccak256(receiver.getSender(OPTIMISM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[1].sender.proxy)),
                "_verifyDeployments::9"
            );
            require(
                keccak256(receiver.getSender(BASE_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[2].sender.proxy)),
                "_verifyDeployments::10"
            );
            require(
                _getProxyAdmin(l1Contracts.receiver.proxy) == l1Contracts.receiver.proxyAdmin, "_verifyDeployments::11"
            );
            _checkOwner(l1Contracts.receiver.proxyAdmin, deployer, ETHEREUM_OWNER, "_verifyDeployments::12");
            require(
                _getProxyImplementation(l1Contracts.receiver.proxy) == l1Contracts.receiver.implementation,
                "_verifyDeployments::13"
            );

            ArbitrumLegacyAdapterL1toL2 arbAdapter = ArbitrumLegacyAdapterL1toL2(l1Contracts.arbitrumAdapter);

            require(arbAdapter.L1_GATEWAY_ROUTER() == ETHEREUM_TO_ARBITRUM_ROUTER, "_verifyDeployments::14");
            require(arbAdapter.L1_TOKEN() == ETHEREUM_WSTETH_TOKEN, "_verifyDeployments::15");
            require(
                arbAdapter.L1_TOKEN_GATEWAY()
                    == IArbitrumL1GatewayRouter(ETHEREUM_TO_ARBITRUM_ROUTER).l1TokenToGateway(ETHEREUM_WSTETH_TOKEN),
                "_verifyDeployments::16"
            );
            require(arbAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "_verifyDeployments::17");

            OptimismLegacyAdapterL1toL2 optAdapter = OptimismLegacyAdapterL1toL2(l1Contracts.optimismAdapter);

            require(optAdapter.L1_ERC20_BRIDGE() == ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE, "_verifyDeployments::18");
            require(
                optAdapter.L1_TOKEN() == IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).l1Token(),
                "_verifyDeployments::19"
            );
            require(
                optAdapter.L2_TOKEN() == IOptimismL1ERC20TokenBridge(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE).l2Token(),
                "_verifyDeployments::20"
            );
            require(optAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "_verifyDeployments::21");

            BaseLegacyAdapterL1toL2 baseAdapter = BaseLegacyAdapterL1toL2(l1Contracts.baseAdapter);

            require(baseAdapter.L1_ERC20_BRIDGE() == ETHEREUM_TO_BASE_WSTETH_TOKEN_BRIDGE, "_verifyDeployments::22");
            require(baseAdapter.L1_TOKEN() == ETHEREUM_WSTETH_TOKEN, "_verifyDeployments::23");
            require(baseAdapter.L2_TOKEN() == BASE_WSTETH_TOKEN, "_verifyDeployments::24");
            require(baseAdapter.DELEGATOR() == l1Contracts.receiver.proxy, "_verifyDeployments::25");
        }

        vm.selectFork(arbitrumForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            require(priceOracle.AGGREGATOR() == ARBITRUM_WSTETH_STETH_DATAFEED, "_verifyDeployments::26");
            require(priceOracle.IS_INVERSE() == ARBITRUM_WSTETH_STETH_DATAFEED_IS_INVERSE, "_verifyDeployments::27");
            require(priceOracle.HEARTBEAT() == ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT, "_verifyDeployments::28");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(ARBITRUM_WSTETH_STETH_DATAFEED).decimals(),
                "_verifyDeployments::29"
            );

            PausableImmutableOraclePool oraclePool = PausableImmutableOraclePool(l2Contracts[0].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::30");
            require(oraclePool.TOKEN_IN() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::31");
            require(oraclePool.TOKEN_OUT() == ARBITRUM_WSTETH_TOKEN, "_verifyDeployments::32");
            require(oraclePool.getOracle() == l2Contracts[0].priceOracle, "_verifyDeployments::33");
            require(oraclePool.getFee() == ARBITRUM_ORACLE_POOL_FEE, "_verifyDeployments::34");
            _checkOwner(address(oraclePool), deployer, ARBITRUM_OWNER, "_verifyDeployments::35");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            require(sender.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::36");
            require(sender.LINK_TOKEN() == ARBITRUM_LINK_TOKEN, "_verifyDeployments::37");
            require(sender.CCIP_ROUTER() == ARBITRUM_CCIP_ROUTER, "_verifyDeployments::38");
            require(sender.getOraclePool() == l2Contracts[0].oraclePool, "_verifyDeployments::39");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, ARBITRUM_OWNER, "_verifyDeployments::40");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), "_verifyDeployments::41");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::42"
            );
            require(
                _getProxyAdmin(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.proxyAdmin,
                "_verifyDeployments::43"
            );
            _checkOwner(l2Contracts[0].sender.proxyAdmin, deployer, ARBITRUM_OWNER, "_verifyDeployments::44");
            require(
                _getProxyImplementation(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.implementation,
                "_verifyDeployments::45"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::46");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::47");
            require(syncAutomation.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::48");
            _checkOwner(address(syncAutomation), deployer, ARBITRUM_OWNER, "_verifyDeployments::49");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::50");
            require(syncAutomation.getDelay() == ARBITRUM_MIN_SYNC_DELAY, "_verifyDeployments::51");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::52"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO())
                    == keccak256(
                        FeeCodec.encodeArbitrumL1toL2(
                            ARBITRUM_ORIGIN_MAX_SUBMISSION_COST, ARBITRUM_ORIGIN_MAX_GAS, ARBITRUM_ORIGIN_GAS_PRICE_BID
                        )
                    ),
                "_verifyDeployments::53"
            );
            (uint256 minSyncAmount, uint256 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == ARBITRUM_MIN_SYNC_AMOUNT, "_verifyDeployments::54");
            require(maxSyncAmount == ARBITRUM_MAX_SYNC_AMOUNT, "_verifyDeployments::55");
        }

        vm.selectFork(optimismForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[1].priceOracle);

            require(priceOracle.AGGREGATOR() == OPTIMISM_WSTETH_STETH_DATAFEED, "_verifyDeployments::56");
            require(priceOracle.IS_INVERSE() == OPTIMISM_WSTETH_STETH_DATAFEED_IS_INVERSE, "_verifyDeployments::57");
            require(priceOracle.HEARTBEAT() == OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT, "_verifyDeployments::58");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(OPTIMISM_WSTETH_STETH_DATAFEED).decimals(),
                "_verifyDeployments::59"
            );

            PausableImmutableOraclePool oraclePool = PausableImmutableOraclePool(l2Contracts[1].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[1].sender.proxy, "_verifyDeployments::60");
            require(oraclePool.TOKEN_IN() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::61");
            require(oraclePool.TOKEN_OUT() == OPTIMISM_WSTETH_TOKEN, "_verifyDeployments::62");
            require(oraclePool.getOracle() == l2Contracts[1].priceOracle, "_verifyDeployments::63");
            require(oraclePool.getFee() == OPTIMISM_ORACLE_POOL_FEE, "_verifyDeployments::64");
            _checkOwner(address(oraclePool), deployer, OPTIMISM_OWNER, "_verifyDeployments::65");

            CustomSender sender = CustomSender(l2Contracts[1].sender.proxy);

            require(sender.WNATIVE() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::66");
            require(sender.LINK_TOKEN() == OPTIMISM_LINK_TOKEN, "_verifyDeployments::67");
            require(sender.CCIP_ROUTER() == OPTIMISM_CCIP_ROUTER, "_verifyDeployments::68");
            require(sender.getOraclePool() == l2Contracts[1].oraclePool, "_verifyDeployments::69");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, OPTIMISM_OWNER, "_verifyDeployments::70");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[1].syncAutomation), "_verifyDeployments::71");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::72"
            );
            require(
                _getProxyAdmin(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.proxyAdmin,
                "_verifyDeployments::73"
            );
            _checkOwner(l2Contracts[1].sender.proxyAdmin, deployer, OPTIMISM_OWNER, "_verifyDeployments::74");
            require(
                _getProxyImplementation(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.implementation,
                "_verifyDeployments::75"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[1].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[1].sender.proxy, "_verifyDeployments::76");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::77");
            require(syncAutomation.WNATIVE() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::78");
            _checkOwner(address(syncAutomation), deployer, OPTIMISM_OWNER, "_verifyDeployments::79");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::80");
            require(syncAutomation.getDelay() == OPTIMISM_MIN_SYNC_DELAY, "_verifyDeployments::81");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::82"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO())
                    == keccak256(FeeCodec.encodeOptimismL1toL2(OPTIMISM_ORIGIN_L2_GAS)),
                "_verifyDeployments::83"
            );
            (uint256 minSyncAmount, uint256 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == OPTIMISM_MIN_SYNC_AMOUNT, "_verifyDeployments::84");
            require(maxSyncAmount == OPTIMISM_MAX_SYNC_AMOUNT, "_verifyDeployments::85");
        }

        vm.selectFork(baseForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[2].priceOracle);

            require(priceOracle.AGGREGATOR() == BASE_WSTETH_STETH_DATAFEED, "_verifyDeployments::86");
            require(priceOracle.IS_INVERSE() == BASE_WSTETH_STETH_DATAFEED_IS_INVERSE, "_verifyDeployments::87");
            require(priceOracle.HEARTBEAT() == BASE_WSTETH_STETH_DATAFEED_HEARTBEAT, "_verifyDeployments::88");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(BASE_WSTETH_STETH_DATAFEED).decimals(),
                "_verifyDeployments::89"
            );

            PausableImmutableOraclePool oraclePool = PausableImmutableOraclePool(l2Contracts[2].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[2].sender.proxy, "_verifyDeployments::90");
            require(oraclePool.TOKEN_IN() == BASE_WETH_TOKEN, "_verifyDeployments::91");
            require(oraclePool.TOKEN_OUT() == BASE_WSTETH_TOKEN, "_verifyDeployments::92");
            require(oraclePool.getOracle() == l2Contracts[2].priceOracle, "_verifyDeployments::93");
            require(oraclePool.getFee() == BASE_ORACLE_POOL_FEE, "_verifyDeployments::94");
            _checkOwner(address(oraclePool), deployer, BASE_OWNER, "_verifyDeployments::95");

            CustomSender sender = CustomSender(l2Contracts[2].sender.proxy);

            require(sender.WNATIVE() == BASE_WETH_TOKEN, "_verifyDeployments::96");
            require(sender.LINK_TOKEN() == BASE_LINK_TOKEN, "_verifyDeployments::97");
            require(sender.CCIP_ROUTER() == BASE_CCIP_ROUTER, "_verifyDeployments::98");
            require(sender.getOraclePool() == l2Contracts[2].oraclePool, "_verifyDeployments::99");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, BASE_OWNER, "_verifyDeployments::100");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[2].syncAutomation), "_verifyDeployments::101");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::102"
            );
            require(
                _getProxyAdmin(l2Contracts[2].sender.proxy) == l2Contracts[2].sender.proxyAdmin,
                "_verifyDeployments::103"
            );
            _checkOwner(l2Contracts[2].sender.proxyAdmin, deployer, BASE_OWNER, "_verifyDeployments::104");
            require(
                _getProxyImplementation(l2Contracts[2].sender.proxy) == l2Contracts[2].sender.implementation,
                "_verifyDeployments::105"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[2].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[2].sender.proxy, "_verifyDeployments::106");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::107");
            require(syncAutomation.WNATIVE() == BASE_WETH_TOKEN, "_verifyDeployments::108");
            _checkOwner(address(syncAutomation), deployer, BASE_OWNER, "_verifyDeployments::109");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::110");
            require(syncAutomation.getDelay() == BASE_MIN_SYNC_DELAY, "_verifyDeployments::111");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::112"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO()) == keccak256(FeeCodec.encodeBaseL1toL2(BASE_ORIGIN_L2_GAS)),
                "_verifyDeployments::113"
            );
            (uint256 minSyncAmount, uint256 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == BASE_MIN_SYNC_AMOUNT, "_verifyDeployments::114");
            require(maxSyncAmount == BASE_MAX_SYNC_AMOUNT, "_verifyDeployments::115");
        }
    }
}
