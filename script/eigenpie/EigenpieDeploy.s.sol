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
                    DEAD_ADDRESS
                )
            );

            l1Contracts.receiver.proxy = address(
                new TransparentUpgradeableProxy(
                    l1Contracts.receiver.implementation,
                    ETHEREUM_OWNER == address(0) ? deployer : ETHEREUM_OWNER,
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

        // Set up contracts on ethereum
        {
            vm.selectFork(ethereumForkId);
            vm.startBroadcast(deployerPrivateKey);

            EigenpieCustomReceiver receiver = EigenpieCustomReceiver(payable(l1Contracts.receiver.proxy));

            receiver.setAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR, l1Contracts.arbitrumAdapter);
            receiver.setSender(ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(arbContracts.sender.proxy));

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
                FeeCodec.encodeCCIP(
                    ARBITRUM_DESTINATION_MAX_FEE, ARBITRUM_DESTINATION_PAY_IN_LINK, ARBITRUM_DESTINATION_GAS_LIMIT
                )
            );

            syncAutomation.setAmounts(ARBITRUM_MIN_SYNC_AMOUNT, ARBITRUM_MAX_SYNC_AMOUNT);
            syncAutomation.setDelay(ARBITRUM_MIN_SYNC_DELAY);

            if (ARBITRUM_OWNER != address(0)) {
                sender.grantRole(sender.DEFAULT_ADMIN_ROLE(), ARBITRUM_OWNER);
                sender.renounceRole(sender.DEFAULT_ADMIN_ROLE(), deployer);
            }

            vm.stopBroadcast();
        }

        _verifyDeployments(l1Contracts, l2Contracts);
    }

    function _verifyDeployments(L1Contracts memory l1Contracts, L2Contracts[] memory l2Contracts) internal {
        vm.selectFork(ethereumForkId);

        {
            EigenpieCustomReceiver receiver = EigenpieCustomReceiver(payable(l1Contracts.receiver.proxy));

            require(receiver.EGETH() == ETHEREUM_EGETH_TOKEN, "_verifyDeployments::1");
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
                keccak256(receiver.getSender(ARBITRUM_CCIP_CHAIN_SELECTOR))
                    == keccak256(abi.encode(l2Contracts[0].sender.proxy)),
                "_verifyDeployments::6"
            );
            require(
                _getProxyAdmin(l1Contracts.receiver.proxy) == l1Contracts.receiver.proxyAdmin, "_verifyDeployments::7"
            );
            _checkOwner(l1Contracts.receiver.proxyAdmin, deployer, ETHEREUM_OWNER, "_verifyDeployments::8");
            require(
                _getProxyImplementation(l1Contracts.receiver.proxy) == l1Contracts.receiver.implementation,
                "_verifyDeployments::9"
            );

            CCIPAdapter ccipAdapter = CCIPAdapter(l1Contracts.arbitrumAdapter);

            require(ccipAdapter.LINK_TOKEN() == ETHEREUM_LINK_TOKEN, "_verifyDeployments::10");
            require(ccipAdapter.CCIP_ROUTER() == ETHEREUM_CCIP_ROUTER, "_verifyDeployments::11");
            require(ccipAdapter.L1_TOKEN() == ETHEREUM_EGETH_TOKEN, "_verifyDeployments::12");
        }

        vm.selectFork(arbitrumForkId);

        {
            PriceOracle priceOracle = PriceOracle(l2Contracts[0].priceOracle);

            (address dataFeed, bool isInverse, uint32 heartbeat, uint8 decimals) = priceOracle.getOracleParameters();

            require(dataFeed == ARBITRUM_EGETH_ETH_DATAFEED, "_verifyDeployments::13");
            require(isInverse == ARBITRUM_EGETH_ETH_DATAFEED_IS_INVERSE, "_verifyDeployments::14");
            require(heartbeat == ARBITRUM_EGETH_ETH_DATAFEED_HEARTBEAT, "_verifyDeployments::15");
            require(AggregatorV3Interface(dataFeed).decimals() == decimals, "_verifyDeployments::16");
            _checkOwner(address(priceOracle), deployer, ARBITRUM_OWNER, "_verifyDeployments::17");

            OraclePool oraclePool = OraclePool(l2Contracts[0].oraclePool);

            require(oraclePool.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::18");
            require(oraclePool.TOKEN_IN() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::19");
            require(oraclePool.TOKEN_OUT() == ARBITRUM_EGETH_TOKEN, "_verifyDeployments::20");
            require(oraclePool.getOracle() == l2Contracts[0].priceOracle, "_verifyDeployments::21");
            require(oraclePool.getFee() == ARBITRUM_ORACLE_POOL_FEE, "_verifyDeployments::22");
            _checkOwner(address(oraclePool), deployer, ARBITRUM_OWNER, "_verifyDeployments::23");

            CustomSender sender = CustomSender(l2Contracts[0].sender.proxy);

            require(sender.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::24");
            require(sender.LINK_TOKEN() == ARBITRUM_LINK_TOKEN, "_verifyDeployments::25");
            require(sender.CCIP_ROUTER() == ARBITRUM_CCIP_ROUTER, "_verifyDeployments::26");
            require(sender.getOraclePool() == l2Contracts[0].oraclePool, "_verifyDeployments::27");
            _checkRole(address(sender), sender.DEFAULT_ADMIN_ROLE(), deployer, ARBITRUM_OWNER, "_verifyDeployments::28");
            require(sender.hasRole(sender.SYNC_ROLE(), l2Contracts[0].syncAutomation), "_verifyDeployments::29");
            require(
                abi.decode(sender.getReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR), (address)) == l1Contracts.receiver.proxy,
                "_verifyDeployments::30"
            );
            require(
                _getProxyAdmin(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.proxyAdmin,
                "_verifyDeployments::31"
            );
            _checkOwner(l2Contracts[0].sender.proxyAdmin, deployer, ARBITRUM_OWNER, "_verifyDeployments::32");
            require(
                _getProxyImplementation(l2Contracts[0].sender.proxy) == l2Contracts[0].sender.implementation,
                "_verifyDeployments::33"
            );

            SyncAutomation syncAutomation = SyncAutomation(l2Contracts[0].syncAutomation);

            require(syncAutomation.SENDER() == l2Contracts[0].sender.proxy, "_verifyDeployments::34");
            require(syncAutomation.DEST_CHAIN_SELECTOR() == ETHEREUM_CCIP_CHAIN_SELECTOR, "_verifyDeployments::35");
            require(syncAutomation.WNATIVE() == ARBITRUM_WETH_TOKEN, "_verifyDeployments::36");
            _checkOwner(address(syncAutomation), deployer, ARBITRUM_OWNER, "_verifyDeployments::37");
            require(syncAutomation.getLastExecution() == block.timestamp, "_verifyDeployments::38");
            require(syncAutomation.getDelay() == ARBITRUM_MIN_SYNC_DELAY, "_verifyDeployments::39");
            require(
                keccak256(abi.encode(syncAutomation.getFeeOtoD()))
                    == keccak256(
                        abi.encode(
                            FeeCodec.encodeCCIP(
                                ETHEREUM_DESTINATION_MAX_FEE,
                                ETHEREUM_DESTINATION_PAY_IN_LINK,
                                ETHEREUM_DESTINATION_GAS_LIMIT
                            )
                        )
                    ),
                "_verifyDeployments::40"
            );
            require(
                keccak256(abi.encode(syncAutomation.getFeeDtoO()))
                    == keccak256(
                        abi.encode(
                            FeeCodec.encodeCCIP(
                                ARBITRUM_DESTINATION_MAX_FEE,
                                ARBITRUM_DESTINATION_PAY_IN_LINK,
                                ARBITRUM_DESTINATION_GAS_LIMIT
                            )
                        )
                    ),
                "_verifyDeployments::41"
            );
            (uint128 minAmount, uint128 maxAmount) = syncAutomation.getAmounts();
            require(minAmount == ARBITRUM_MIN_SYNC_AMOUNT, "_verifyDeployments::42");
            require(maxAmount == ARBITRUM_MAX_SYNC_AMOUNT, "_verifyDeployments::43");
        }
    }
}
