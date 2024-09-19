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
        ethereumForkId = vm.createFork(vm.rpcUrl("ethereum"));
        arbitrumForkId = vm.createFork(vm.rpcUrl("arbitrum"));
        optimismForkId = vm.createFork(vm.rpcUrl("optimism"));
    }

    function run() public returns (L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
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
                    address(0xdead)
                )
            );

            l1Contracts.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    l1Contracts.receiver.implementation,
                    deployer,
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
                    ARBITRUM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT,
                    deployer
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
                    OPTIMISM_SFRXETH_FRXETH_DATAFEED,
                    OPTIMISM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE,
                    OPTIMISM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT,
                    deployer
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

        // Set up contracts on ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            FraxCustomReceiver(payable(l1Contracts.receiver.proxy)).setAdapter(
                ARBITRUM_CCIP_CHAIN_SELECTOR, l1Contracts.arbitrumAdapter
            );
            FraxCustomReceiver(payable(l1Contracts.receiver.proxy)).setAdapter(
                OPTIMISM_CCIP_CHAIN_SELECTOR, l1Contracts.optimismAdapter
            );

            FraxCustomReceiver(payable(l1Contracts.receiver.proxy)).setSender(
                ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(arbContracts.sender.proxy)
            );
            FraxCustomReceiver(payable(l1Contracts.receiver.proxy)).setSender(
                OPTIMISM_CCIP_CHAIN_SELECTOR, abi.encode(optContracts.sender.proxy)
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

        _verifyContracts(l1Contracts, l2Contracts);
    }

    function _verifyContracts(L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) internal {
        vm.selectFork(ethereumForkId);

        {
            FraxCustomReceiver receiver = FraxCustomReceiver(payable(l1Contracts.receiver.proxy));

            require(receiver.SFRXETH() == ETHEREUM_SFRXETH_TOKEN, "FraxDeployScript::1");
            require(receiver.WNATIVE() == ETHEREUM_WETH_TOKEN, "FraxDeployScript::2");
            require(receiver.CCIP_ROUTER() == ETHEREUM_CCIP_ROUTER, "FraxDeployScript::3");
            require(receiver.hasRole(receiver.DEFAULT_ADMIN_ROLE(), deployer), "FraxDeployScript::4");
            require(receiver.getAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR) == l1Contracts.arbitrumAdapter, "FraxDeployScript::5");
            require(receiver.getAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR) == l1Contracts.optimismAdapter, "FraxDeployScript::6");
            require(
                keccak256(receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[0].sender.proxy)),
                "FraxDeployScript::7"
            );
            require(
                keccak256(receiver.getSender(OPTIMISM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[1].sender.proxy)),
                "FraxDeployScript::8"
            );
            require(_getProxyAdmin(l1Contracts.receiver.proxy) == l1Contracts.receiver.proxyAdmin, "FraxDeployScript::9");
            require(ProxyAdmin(l1Contracts.receiver.proxyAdmin).owner() == deployer, "FraxDeployScript::10");
            require(
                _getProxyImplementation(l1Contracts.receiver.proxy) == l1Contracts.receiver.implementation,
                "FraxDeployScript::11"
            );

            FraxFerryAdapterL1toL2 arbAdapter = FraxFerryAdapterL1toL2(l1Contracts.arbitrumAdapter);

            require(arbAdapter.FRAX_FERRY() == ETHEREUM_TO_ARBITRUM_FRAX_FERRY, "FraxDeployScript::12");
            require(arbAdapter.TOKEN() == ETHEREUM_SFRXETH_TOKEN, "FraxDeployScript::13");

            FraxFerryAdapterL1toL2 optAdapter = FraxFerryAdapterL1toL2(l1Contracts.optimismAdapter);

            require(optAdapter.FRAX_FERRY() == ETHEREUM_TO_OPTIMISM_FRAX_FERRY, "FraxDeployScript::14");
            require(optAdapter.TOKEN() == ETHEREUM_SFRXETH_TOKEN, "FraxDeployScript::15");
        }

        vm.selectFork(arbitrumForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            require(dataFeed == ARBITRUM_SFRXETH_FRXETH_DATAFEED, "FraxDeployScript::16");
            require(isInverse == ARBITRUM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE, "FraxDeployScript::17");
            require(heartbeat == ARBITRUM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT, "FraxDeployScript::18");
            require(AggregatorV3Interface(dataFeed).decimals() == decimals, "FraxDeployScript::19");

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[0].sender.proxy, "FraxDeployScript::20");
            require(oraclePool.TOKEN_IN() == ARBITRUM_WETH_TOKEN, "FraxDeployScript::21");
            require(oraclePool.TOKEN_OUT() == ARBITRUM_SFRXETH_TOKEN, "FraxDeployScript::22");
            require(oraclePool.getOracle() == l2Contracts[0].priceOracle, "FraxDeployScript::23");
            require(oraclePool.getFee() == ARBITRUM_ORACLE_POOL_FEE, "FraxDeployScript::24");
            require(oraclePool.owner() == deployer, "FraxDeployScript::25");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            require(sender.WNATIVE() == ARBITRUM_WETH_TOKEN, "FraxDeployScript::26");
            require(sender.LINK_TOKEN() == ARBITRUM_LINK_TOKEN, "FraxDeployScript::27");
            require(sender.CCIP_ROUTER() == ARBITRUM_CCIP_ROUTER, "FraxDeployScript::28");
            require(sender.getOraclePool() == l2Contracts[0].oraclePool, "FraxDeployScript::29");
            require(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), "FraxDeployScript::30");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), "FraxDeployScript::31");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "FraxDeployScript::32"
            );
            require(_getProxyAdmin(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.proxyAdmin, "FraxDeployScript::33");
            require(ProxyAdmin(l2Contracts[0].sender.proxyAdmin).owner() == deployer, "FraxDeployScript::34");
            require(
                _getProxyImplementation(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.implementation,
                "FraxDeployScript::35"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[0].sender.proxy, "FraxDeployScript::36");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "FraxDeployScript::37");
            require(syncAutomation.WNATIVE() == ARBITRUM_WETH_TOKEN, "FraxDeployScript::38");
            require(syncAutomation.owner() == deployer, "FraxDeployScript::39");
            require(syncAutomation.getLastExecution() == block.timestamp, "FraxDeployScript::40");
            require(syncAutomation.getDelay() == type(uint48).max, "FraxDeployScript::41");
        }

        vm.selectFork(optimismForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[1].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            require(dataFeed == OPTIMISM_SFRXETH_FRXETH_DATAFEED, "FraxDeployScript::42");
            require(isInverse == OPTIMISM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE, "FraxDeployScript::43");
            require(heartbeat == OPTIMISM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT, "FraxDeployScript::44");
            require(AggregatorV3Interface(dataFeed).decimals() == decimals, "FraxDeployScript::45");

            OraclePool oraclePool = OraclePool(l2Contracts[1].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[1].sender.proxy, "FraxDeployScript::46");
            require(oraclePool.TOKEN_IN() == OPTIMISM_WETH_TOKEN, "FraxDeployScript::47");
            require(oraclePool.TOKEN_OUT() == OPTIMISM_SFRXETH_TOKEN, "FraxDeployScript::48");
            require(oraclePool.getOracle() == l2Contracts[1].priceOracle, "FraxDeployScript::49");
            require(oraclePool.getFee() == OPTIMISM_ORACLE_POOL_FEE, "FraxDeployScript::50");
            require(oraclePool.owner() == deployer, "FraxDeployScript::51");

            CustomSender sender = CustomSender(l2Contracts[1].sender.proxy);

            require(sender.WNATIVE() == OPTIMISM_WETH_TOKEN, "FraxDeployScript::52");
            require(sender.LINK_TOKEN() == OPTIMISM_LINK_TOKEN, "FraxDeployScript::53");
            require(sender.CCIP_ROUTER() == OPTIMISM_CCIP_ROUTER, "FraxDeployScript::54");
            require(sender.getOraclePool() == l2Contracts[1].oraclePool, "FraxDeployScript::55");
            require(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), "FraxDeployScript::56");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[1].syncAutomation), "FraxDeployScript::57");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "FraxDeployScript::58"
            );
            require(_getProxyAdmin(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.proxyAdmin, "FraxDeployScript::59");
            require(ProxyAdmin(l2Contracts[1].sender.proxyAdmin).owner() == deployer, "FraxDeployScript::60");
            require(
                _getProxyImplementation(l2Contracts[1].sender.proxy) == l2Contracts[1].sender.implementation,
                "FraxDeployScript::61"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[1].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[1].sender.proxy, "FraxDeployScript::62");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "FraxDeployScript::63");
            require(syncAutomation.WNATIVE() == OPTIMISM_WETH_TOKEN, "FraxDeployScript::64");
            require(syncAutomation.owner() == deployer, "FraxDeployScript::65");
            require(syncAutomation.getLastExecution() == block.timestamp, "FraxDeployScript::66");
            require(syncAutomation.getDelay() == type(uint48).max, "FraxDeployScript::67");
        }
    }
}
