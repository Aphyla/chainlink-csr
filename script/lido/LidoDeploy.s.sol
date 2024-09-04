// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./LidoParameters.sol";

import "../../contracts/senders/CustomSender.sol";
import "../../contracts/receivers/LidoCustomReceiver.sol";
import "../../contracts/adapters/ArbitrumLegacyAdapterL1toL2.sol";
import "../../contracts/adapters/OptimismLegacyAdapterL1toL2.sol";
import "../../contracts/adapters/BaseAdapterL1toL2.sol";
import "../../contracts/automations/SyncAutomation.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";

contract LidoDeployScript is Script, LidoParameters {
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
                new LidoCustomReceiver(ETHEREUM_WSTETH_TOKEN, ETHEREUM_WETH_TOKEN, ETHEREUM_CCIP_ROUTER, address(0))
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

            l1Contracts.baseAdapter = address(
                new BaseAdapterL1toL2(
                    ETHEREUM_TO_BASE_STANDARD_BRIDGE,
                    ETHEREUM_WSTETH_TOKEN,
                    BASE_WSTETH_TOKEN,
                    l1Contracts.receiver.proxy
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
                    address(0),
                    address(0)
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
                    address(0),
                    address(0)
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
                    BASE_WETH_TOKEN, BASE_WETH_TOKEN, BASE_LINK_TOKEN, BASE_CCIP_ROUTER, address(0), address(0)
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
    }

    function _predictContractAddress(address account, uint256 deltaNonce) private view returns (address) {
        uint256 nonce = vm.getNonce(account) + deltaNonce;
        return vm.computeCreateAddress(account, nonce);
    }

    function _getProxyAdmin(address proxy) private view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }
}
