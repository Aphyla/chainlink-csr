// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./FraxParameters.sol";

import "../../contracts/senders/CustomSender.sol";
import "../../contracts/receivers/FraxCustomReceiver.sol";
import "../../contracts/adapters/FraxFerryAdapterL1toL2.sol";
import "../../contracts/automations/SyncAutomation.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";

contract FraxDeployScript is Script, FraxParameters {
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
                    address(0)
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
                new CustomSender(ARBITRUM_WETH_TOKEN,ARBITRUM_WETH_TOKEN, ARBITRUM_LINK_TOKEN, ARBITRUM_CCIP_ROUTER, address(0), address(0))
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
                new CustomSender(OPTIMISM_WETH_TOKEN,OPTIMISM_WETH_TOKEN, OPTIMISM_LINK_TOKEN, OPTIMISM_CCIP_ROUTER, address(0), address(0))
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
    }

    function _predictContractAddress(address account, uint256 deltaNonce) private view returns (address) {
        uint256 nonce = vm.getNonce(account) + deltaNonce;
        return vm.computeCreateAddress(account, nonce);
    }

    function _getProxyAdmin(address proxy) private view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }
}
