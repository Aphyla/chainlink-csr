// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./EigenpieParameters.sol";

import "../ScriptHelper.sol";
import "../../contracts/senders/CustomSender.sol";
import "../../contracts/receivers/EigenpieCustomReceiver.sol";
import "../../contracts/adapters/CCIPAdapter.sol";
import "../../contracts/automations/SyncAutomation.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";

contract EigenpieDeployScript is ScriptHelper, EigenpieParameters {
    struct Proxy {
        address proxy;
        address proxyAdmin;
        address implementation;
    }

    struct L1Contracts {
        string chainName;
        Proxy receiver;
        address arbitrumAdapter;
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

    address public deployer;

    function setUp() public {
        ethereumForkId = vm.createFork(vm.rpcUrl("ethereum"));
        arbitrumForkId = vm.createFork(vm.rpcUrl("arbitrum"));
    }

    function run() public returns (L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        l1Contracts.chainName = "Ethereum";

        l2Contracts = new L2Contracts[](1);

        L2Contracts memory arbContracts = l2Contracts[0];

        arbContracts.chainName = "Arbitrum";

        // Deploy contracts on Ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            l1Contracts.receiver.implementation = address(
                new EigenpieCustomReceiver(
                    ETHEREUM_EGETH_TOKEN,
                    ETHEREUM_EGETH_STAKING,
                    ETHEREUM_WETH_TOKEN,
                    ETHEREUM_CCIP_ROUTER,
                    address(0xdead)
                )
            );

            l1Contracts.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    l1Contracts.receiver.implementation,
                    deployer,
                    abi.encodeCall(EigenpieCustomReceiver.initialize, (deployer))
                )
            );

            l1Contracts.receiver.proxyAdmin = _getProxyAdmin(l1Contracts.receiver.proxy);

            l1Contracts.arbitrumAdapter = address(
                new CCIPAdapter(
                    ETHEREUM_EGETH_TOKEN, ETHEREUM_CCIP_ROUTER, ETHEREUM_LINK_TOKEN, l1Contracts.receiver.proxy
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
                    ARBITRUM_EGETH_ETH_DATAFEED,
                    ARBITRUM_EGETH_ETH_DATAFEED_IS_INVERSE,
                    ARBITRUM_EGETH_ETH_DATAFEED_HEARTBEAT,
                    deployer
                )
            );

            arbContracts.oraclePool = address(
                new OraclePool(
                    _predictContractAddress(deployer, 2), // As we deploy this contract, the impementation and then the proxy, we need to increment the nonce by 2
                    ARBITRUM_WETH_TOKEN,
                    ARBITRUM_EGETH_TOKEN,
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

        // Set up contracts on ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            EigenpieCustomReceiver(payable(l1Contracts.receiver.proxy)).setAdapter(
                ARBITRUM_CCIP_CHAIN_SELECTOR, l1Contracts.arbitrumAdapter
            );
            EigenpieCustomReceiver(payable(l1Contracts.receiver.proxy)).setSender(
                ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(arbContracts.sender.proxy)
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

        _verifyContracts(l1Contracts, l2Contracts);
    }

    function _verifyContracts(L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) internal {
        vm.selectFork(ethereumForkId);

        {
            EigenpieCustomReceiver receiver = EigenpieCustomReceiver(payable(l1Contracts.receiver.proxy));

            require(receiver.EGETH() == ETHEREUM_EGETH_TOKEN, "EigenpieDeployScript::1");
            require(receiver.WNATIVE() == ETHEREUM_WETH_TOKEN, "EigenpieDeployScript::2");
            require(receiver.CCIP_ROUTER() == ETHEREUM_CCIP_ROUTER, "EigenpieDeployScript::3");
            require(receiver.hasRole(receiver.DEFAULT_ADMIN_ROLE(), deployer), "EigenpieDeployScript::4");
            require(
                receiver.getAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR) == l1Contracts.arbitrumAdapter,
                "EigenpieDeployScript::5"
            );
            require(
                keccak256(receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[0].sender.proxy)),
                "EigenpieDeployScript::6"
            );
            require(
                _getProxyAdmin(l1Contracts.receiver.proxy) == l1Contracts.receiver.proxyAdmin, "EigenpieDeployScript::7"
            );
            require(ProxyAdmin(l1Contracts.receiver.proxyAdmin).owner() == deployer, "EigenpieDeployScript::8");
            require(
                _getProxyImplementation(l1Contracts.receiver.proxy) == l1Contracts.receiver.implementation,
                "EigenpieDeployScript::9"
            );

            CCIPAdapter ccipAdapter = CCIPAdapter(l1Contracts.arbitrumAdapter);

            require(ccipAdapter.LINK_TOKEN() == ETHEREUM_LINK_TOKEN, "EigenpieDeployScript::10");
            require(ccipAdapter.CCIP_ROUTER() == ETHEREUM_CCIP_ROUTER, "EigenpieDeployScript::11");
            require(ccipAdapter.L1_TOKEN() == ETHEREUM_EGETH_TOKEN, "EigenpieDeployScript::12");
        }

        vm.selectFork(arbitrumForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            require(dataFeed == ARBITRUM_EGETH_ETH_DATAFEED, "EigenpieDeployScript::13");
            require(isInverse == ARBITRUM_EGETH_ETH_DATAFEED_IS_INVERSE, "EigenpieDeployScript::14");
            require(heartbeat == ARBITRUM_EGETH_ETH_DATAFEED_HEARTBEAT, "EigenpieDeployScript::15");
            require(AggregatorV3Interface(dataFeed).decimals() == decimals, "EigenpieDeployScript::16");

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[0].sender.proxy, "EigenpieDeployScript::17");
            require(oraclePool.TOKEN_IN() == ARBITRUM_WETH_TOKEN, "EigenpieDeployScript::18");
            require(oraclePool.TOKEN_OUT() == ARBITRUM_EGETH_TOKEN, "EigenpieDeployScript::19");
            require(oraclePool.getOracle() == l2Contracts[0].priceOracle, "EigenpieDeployScript::20");
            require(oraclePool.getFee() == ARBITRUM_ORACLE_POOL_FEE, "EigenpieDeployScript::21");
            require(oraclePool.owner() == deployer, "EigenpieDeployScript::22");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            require(sender.WNATIVE() == ARBITRUM_WETH_TOKEN, "EigenpieDeployScript::23");
            require(sender.LINK_TOKEN() == ARBITRUM_LINK_TOKEN, "EigenpieDeployScript::24");
            require(sender.CCIP_ROUTER() == ARBITRUM_CCIP_ROUTER, "EigenpieDeployScript::25");
            require(sender.getOraclePool() == l2Contracts[0].oraclePool, "EigenpieDeployScript::26");
            require(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), deployer), "EigenpieDeployScript::27");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), "EigenpieDeployScript::28");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "EigenpieDeployScript::29"
            );
            require(
                _getProxyAdmin(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.proxyAdmin,
                "EigenpieDeployScript::30"
            );
            require(ProxyAdmin(l2Contracts[0].sender.proxyAdmin).owner() == deployer, "EigenpieDeployScript::31");
            require(
                _getProxyImplementation(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.implementation,
                "EigenpieDeployScript::32"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[0].sender.proxy, "EigenpieDeployScript::33");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "EigenpieDeployScript::34");
            require(syncAutomation.WNATIVE() == ARBITRUM_WETH_TOKEN, "EigenpieDeployScript::35");
            require(syncAutomation.owner() == deployer, "EigenpieDeployScript::36");
            require(syncAutomation.getLastExecution() == block.timestamp, "EigenpieDeployScript::37");
            require(syncAutomation.getDelay() == type(uint48).max, "EigenpieDeployScript::38");
        }
    }
}
