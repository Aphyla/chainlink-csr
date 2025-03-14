// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./FraxParameters.sol";

import "../ScriptHelper.sol";
import "../../contracts/senders/CustomSender.sol";
import "../../contracts/receivers/FraxCustomReceiver.sol";
import "../../contracts/adapters/FraxFerryAdapterL1toL2.sol";
import "../../contracts/automations/SyncAutomation.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";

contract FraxDeployScript is ScriptHelper, FraxParameters {
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

    address public deployer;

    function setUp() public {
        ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"));
        arbitrumForkId = vm.createFork(vm.rpcUrl("arbitrum"));
        optimismForkId = vm.createFork(vm.rpcUrl("optimism"));
    }

    function run() public returns (L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) {
        uint256 deployerPrivateKey = vm.envUint("FRAX_DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        l1Contracts.chainName = "Ethereum";

        l2Contracts = new L2Contracts[](2);

        L2Contracts memory arbContracts = l2Contracts[0];
        L2Contracts memory optContracts = l2Contracts[1];

        arbContracts.chainName = "Arbitrum";
        optContracts.chainName = "Optimism";

        // Deploy contracts on Ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            l1Contracts.receiver.implementation = address(
                new FraxCustomReceiver(
                    ETHEREUM_SFRXETH_TOKEN,
                    ETHEREUM_FRXETH_MINTER,
                    ETHEREUM_WETH_TOKEN,
                    ETHEREUM_CCIP_ROUTER,
                    DEAD_ADDRESS
                )
            );

            l1Contracts.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    l1Contracts.receiver.implementation,
                    ETHEREUM_OWNER == address(0) ? deployer : ETHEREUM_OWNER,
                    abi.encodeCall(FraxCustomReceiver.initialize, (deployer))
                )
            );

            l1Contracts.receiver.proxyAdmin = _getProxyAdmin(l1Contracts.receiver.proxy);

            l1Contracts.arbitrumAdapter = address(
                new FraxFerryAdapterL1toL2(
                    ETHEREUM_TO_ARBITRUM_FRAX_FERRY, ETHEREUM_SFRXETH_TOKEN, l1Contracts.receiver.proxy
                )
            );

            l1Contracts.optimismAdapter = address(
                new FraxFerryAdapterL1toL2(
                    ETHEREUM_TO_OPTIMISM_FRAX_FERRY, ETHEREUM_SFRXETH_TOKEN, l1Contracts.receiver.proxy
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
                    ARBITRUM_SFRXETH_FRXETH_DATAFEED,
                    ARBITRUM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE,
                    ARBITRUM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT
                )
            );

            arbContracts.oraclePool = address(
                new OraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the impementation and then the proxy, we need to increment the nonce by 2
                    ARBITRUM_WETH_TOKEN,
                    ARBITRUM_SFRXETH_TOKEN,
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
                    OPTIMISM_SFRXETH_FRXETH_DATAFEED,
                    OPTIMISM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE,
                    OPTIMISM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT
                )
            );

            optContracts.oraclePool = address(
                new OraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the impementation and then the proxy, we need to increment the nonce by 2
                    OPTIMISM_WETH_TOKEN,
                    OPTIMISM_SFRXETH_TOKEN,
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

        // Set up contracts on Ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            FraxCustomReceiver receiver = FraxCustomReceiver(payable(l1Contracts.receiver.proxy));

            receiver.setAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR, l1Contracts.arbitrumAdapter);
            receiver.setAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR, l1Contracts.optimismAdapter);

            receiver.setSender(ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(arbContracts.sender.proxy));
            receiver.setSender(OPTIMISM_CCIP_CHAIN_SELECTOR, abi.encode(optContracts.sender.proxy));

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
            syncAutomation.setFeeDtoO(FeeCodec.encodeFraxFerryL1toL2());

            syncAutomation.setAmounts(ARBITRUM_MIN_SYNC_AMOUNT, ARBITRUM_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(ARBITRUM_MIN_SYNC_DELAY);

            if (ARBITRUM_OWNER != address(0)) {
                OraclePool(arbContracts.oraclePool).transferOwnership(ARBITRUM_OWNER);
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
            syncAutomation.setFeeDtoO(FeeCodec.encodeFraxFerryL1toL2());

            syncAutomation.setAmounts(OPTIMISM_MIN_SYNC_AMOUNT, OPTIMISM_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(OPTIMISM_MIN_SYNC_DELAY);

            if (OPTIMISM_OWNER != address(0)) {
                OraclePool(optContracts.oraclePool).transferOwnership(OPTIMISM_OWNER);
                Ownable(address(syncAutomation)).transferOwnership(OPTIMISM_OWNER);

                sender.grantRole(sender.DEFAULT_ADMIN_ROLE(), OPTIMISM_OWNER);
                sender.renounceRole(sender.DEFAULT_ADMIN_ROLE(), deployer);
            }

            vm.stopBroadcast();
        }

        _verifyDeployments(l1Contracts, l2Contracts);
    }

    function _verifyDeployments(L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) internal {
        vm.selectFork(ethereumForkId);

        {
            FraxCustomReceiver receiver = FraxCustomReceiver(payable(l1Contracts.receiver.proxy));

            require(receiver.SFRXETH() == ETHEREUM_SFRXETH_TOKEN, "_verifyDeployments::1");
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
            require(
                keccak256(receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[0].sender.proxy)),
                "_verifyDeployments::7"
            );
            require(
                keccak256(receiver.getSender(OPTIMISM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[1].sender.proxy)),
                "_verifyDeployments::8"
            );
            require(
                _getProxyAdmin(l1Contracts.receiver.proxy) == l1Contracts.receiver.proxyAdmin, "_verifyDeployments::9"
            );
            _checkOwner(l1Contracts.receiver.proxyAdmin, deployer, ETHEREUM_OWNER, "_verifyDeployments::10");
            require(
                _getProxyImplementation(l1Contracts.receiver.proxy) == l1Contracts.receiver.implementation,
                "_verifyDeployments::11"
            );

            FraxFerryAdapterL1toL2 arbAdapter = FraxFerryAdapterL1toL2(l1Contracts.arbitrumAdapter);

            require(arbAdapter.FRAX_FERRY() == ETHEREUM_TO_ARBITRUM_FRAX_FERRY, "_verifyDeployments::12");
            require(arbAdapter.TOKEN() == ETHEREUM_SFRXETH_TOKEN, "_verifyDeployments::13");

            FraxFerryAdapterL1toL2 optAdapter = FraxFerryAdapterL1toL2(l1Contracts.optimismAdapter);

            require(optAdapter.FRAX_FERRY() == ETHEREUM_TO_OPTIMISM_FRAX_FERRY, "_verifyDeployments::14");
            require(optAdapter.TOKEN() == ETHEREUM_SFRXETH_TOKEN, "_verifyDeployments::15");
        }

        vm.selectFork(arbitrumForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            require(priceOracle.AGGREGATOR() == ARBITRUM_SFRXETH_FRXETH_DATAFEED, "_verifyDeployments::16");
            require(priceOracle.IS_INVERSE() == ARBITRUM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE, "_verifyDeployments::17");
            require(priceOracle.HEARTBEAT() == ARBITRUM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT, "_verifyDeployments::18");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(ARBITRUM_SFRXETH_FRXETH_DATAFEED).decimals(),
                "_verifyDeployments::19"
            );

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::20");
            require(oraclePool.TOKEN_IN() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::21");
            require(oraclePool.TOKEN_OUT() == ARBITRUM_SFRXETH_TOKEN, "_verifyDeployments::22");
            require(oraclePool.getOracle() == l2Contracts[0].priceOracle, "_verifyDeployments::23");
            require(oraclePool.getFee() == ARBITRUM_ORACLE_POOL_FEE, "_verifyDeployments::24");
            require(oraclePool.owner() == deployer, "_verifyDeployments::25");
            _checkOwner(address(oraclePool), deployer, ARBITRUM_OWNER, "_verifyDeployments::26");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            require(sender.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::27");
            require(sender.LINK_TOKEN() == ARBITRUM_LINK_TOKEN, "_verifyDeployments::28");
            require(sender.CCIP_ROUTER() == ARBITRUM_CCIP_ROUTER, "_verifyDeployments::29");
            require(sender.getOraclePool() == l2Contracts[0].oraclePool, "_verifyDeployments::30");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, ARBITRUM_OWNER, "_verifyDeployments::31");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), "_verifyDeployments::32");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::33"
            );
            require(
                _getProxyAdmin(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.proxyAdmin,
                "_verifyDeployments::34"
            );
            _checkOwner(l2Contracts[0].sender.proxyAdmin, deployer, ARBITRUM_OWNER, "_verifyDeployments::35");
            require(
                _getProxyImplementation(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.implementation,
                "_verifyDeployments::36"
            );

            ISyncAutomation syncAutomation = ISyncAutomation(l2Contracts[0].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::37");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::38");
            require(syncAutomation.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::39");
            _checkOwner(address(syncAutomation), deployer, ARBITRUM_OWNER, "_verifyDeployments::40");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::41");
            require(syncAutomation.getDelay() == ARBITRUM_MIN_SYNC_DELAY, "_verifyDeployments::42");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::43"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO()) == keccak256(FeeCodec.encodeFraxFerryL1toL2()),
                "_verifyDeployments::44"
            );
            (uint128 minSyncAmount, uint128 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == ARBITRUM_MIN_SYNC_AMOUNT, "_verifyDeployments::45");
            require(maxSyncAmount == ARBITRUM_MAX_SYNC_AMOUNT, "_verifyDeployments::46");
        }

        vm.selectFork(optimismForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[1].priceOracle);

            require(priceOracle.AGGREGATOR() == OPTIMISM_SFRXETH_FRXETH_DATAFEED, "_verifyDeployments::47");
            require(priceOracle.IS_INVERSE() == OPTIMISM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE, "_verifyDeployments::48");
            require(priceOracle.HEARTBEAT() == OPTIMISM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT, "_verifyDeployments::49");
            require(
                priceOracle.DECIMALS() == AggregatorV3Interface(OPTIMISM_SFRXETH_FRXETH_DATAFEED).decimals(),
                "_verifyDeployments::50"
            );

            OraclePool oraclePool = OraclePool(l2Contracts[1].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[1].sender.proxy, "_verifyDeployments::51");
            require(oraclePool.TOKEN_IN() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::52");
            require(oraclePool.TOKEN_OUT() == OPTIMISM_SFRXETH_TOKEN, "_verifyDeployments::53");
            require(oraclePool.getOracle() == l2Contracts[1].priceOracle, "_verifyDeployments::54");
            require(oraclePool.getFee() == OPTIMISM_ORACLE_POOL_FEE, "_verifyDeployments::55");
            require(oraclePool.owner() == deployer, "_verifyDeployments::56");
            _checkOwner(address(oraclePool), deployer, OPTIMISM_OWNER, "_verifyDeployments::57");

            CustomSender sender = CustomSender(l2Contracts[1].sender.proxy);

            require(sender.WNATIVE() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::58");
            require(sender.LINK_TOKEN() == OPTIMISM_LINK_TOKEN, "_verifyDeployments::59");
            require(sender.CCIP_ROUTER() == OPTIMISM_CCIP_ROUTER, "_verifyDeployments::60");
            require(sender.getOraclePool() == l2Contracts[1].oraclePool, "_verifyDeployments::61");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, OPTIMISM_OWNER, "_verifyDeployments::62");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[1].syncAutomation), "_verifyDeployments::63");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::64"
            );
            require(
                _getProxyAdmin(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.proxyAdmin,
                "_verifyDeployments::65"
            );
            _checkOwner(l2Contracts[1].sender.proxyAdmin, deployer, OPTIMISM_OWNER, "_verifyDeployments::66");
            require(
                _getProxyImplementation(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.implementation,
                "_verifyDeployments::67"
            );

            ISyncAutomation syncAutomation = ISyncAutomation(l2Contracts[1].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[1].sender.proxy, "_verifyDeployments::68");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::69");
            require(syncAutomation.WNATIVE() == OPTIMISM_WETH_TOKEN, "_verifyDeployments::70");
            _checkOwner(address(syncAutomation), deployer, OPTIMISM_OWNER, "_verifyDeployments::71");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::72");
            require(syncAutomation.getDelay() == OPTIMISM_MIN_SYNC_DELAY, "_verifyDeployments::73");
            require(
                keccak256(syncAutomation.getFeeOtoD())
                    == keccak256(
                        FeeCodec.encodeCCIP(
                            ETHEREUM_DESTINATION_MAX_FEE, ETHEREUM_DESTINATION_PAY_IN_LINK, ETHEREUM_DESTINATION_GAS_LIMIT
                        )
                    ),
                "_verifyDeployments::74"
            );
            require(
                keccak256(syncAutomation.getFeeDtoO()) == keccak256(FeeCodec.encodeFraxFerryL1toL2()),
                "_verifyDeployments::75"
            );
            (uint128 minSyncAmount, uint128 maxSyncAmount) = syncAutomation.getAmounts();
            require(minSyncAmount == OPTIMISM_MIN_SYNC_AMOUNT, "_verifyDeployments::76");
            require(maxSyncAmount == OPTIMISM_MAX_SYNC_AMOUNT, "_verifyDeployments::77");
        }
    }
}
