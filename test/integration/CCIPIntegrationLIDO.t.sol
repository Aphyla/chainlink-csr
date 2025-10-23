// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import "../../contracts/adapters/ArbitrumLegacyAdapterL1toL2.sol";

import "../../contracts/adapters/BaseLegacyAdapterL1toL2.sol";
import "../../contracts/adapters/LineaAdapterL1toL2.sol";
import "../../contracts/adapters/OptimismLegacyAdapterL1toL2.sol";
import "../../contracts/receivers/LidoCustomReceiver.sol";
import "../../contracts/senders/CustomSender.sol";

import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";
import "../../script/lido/LidoParameters.sol";

contract fork_CCIPIntegrationLIDOTest is Test, LidoParameters {
    uint256 ethForkId;
    LidoCustomReceiver receiver;
    ArbitrumLegacyAdapterL1toL2 arbAdapter;
    OptimismLegacyAdapterL1toL2 opAdapter;
    BaseLegacyAdapterL1toL2 baseAdapter;
    LineaAdapterL1toL2 lineaAdapter;

    uint256 arbForkId;
    CustomSender arbSender;
    OraclePool arbOraclePool;
    PriceOracle arbPriceOracle;

    uint256 opForkId;
    CustomSender opSender;
    OraclePool opOraclePool;
    PriceOracle opPriceOracle;

    uint256 baseForkId;
    CustomSender baseSender;
    OraclePool baseOraclePool;
    PriceOracle basePriceOracle;

    uint256 lineaForkId;
    CustomSender lineaSender;
    OraclePool lineaOraclePool;
    PriceOracle lineaPriceOracle;

    address alice = makeAddr("alice");

    function setUp() public {
        ethForkId = vm.createFork(vm.rpcUrl("mainnet"), ETHEREUM_FORK_BLOCK);
        arbForkId = vm.createFork(vm.rpcUrl("arbitrum"), ARBITRUM_FORK_BLOCK);
        opForkId = vm.createFork(vm.rpcUrl("optimism"), OPTIMISM_FORK_BLOCK);
        baseForkId = vm.createFork(vm.rpcUrl("base"), BASE_FORK_BLOCK);
        lineaForkId = vm.createFork(vm.rpcUrl("linea"), LINEA_FORK_BLOCK);

        // Deployments
        {
            vm.selectFork(ethForkId);
            receiver =
                new LidoCustomReceiver(ETHEREUM_WSTETH_TOKEN, ETHEREUM_WETH_TOKEN, ETHEREUM_CCIP_ROUTER, address(this));

            arbAdapter =
                new ArbitrumLegacyAdapterL1toL2(ETHEREUM_TO_ARBITRUM_ROUTER, ETHEREUM_WSTETH_TOKEN, address(receiver));
            opAdapter = new OptimismLegacyAdapterL1toL2(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE, address(receiver));
            baseAdapter = new BaseLegacyAdapterL1toL2(ETHEREUM_TO_BASE_WSTETH_TOKEN_BRIDGE, address(receiver));
            lineaAdapter =
                new LineaAdapterL1toL2(ETHEREUM_TO_LINEA_WSTETH_TOKEN_BRIDGE, ETHEREUM_WSTETH_TOKEN, address(receiver));

            vm.label(ETHEREUM_CCIP_ROUTER, "ETH:CCIPRouter");
            vm.label(ETHEREUM_LINK_TOKEN, "ETH:LINK");
            vm.label(ETHEREUM_WETH_TOKEN, "ETH:WETH");
            vm.label(ETHEREUM_WSTETH_TOKEN, "ETH:WstETH");
            vm.label(ETHEREUM_TO_ARBITRUM_ROUTER, "ETH:ArbRouter");
            vm.label(ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE, "ETH:OpWstETHBridge");
            vm.label(ETHEREUM_TO_BASE_WSTETH_TOKEN_BRIDGE, "ETH:BaseWstETHBridge");
            vm.label(ETHEREUM_TO_LINEA_WSTETH_TOKEN_BRIDGE, "ETH:LineaWstETHBridge");
        }

        {
            vm.selectFork(arbForkId);

            arbPriceOracle = new PriceOracle(ARBITRUM_WSTETH_STETH_DATAFEED, false, 24 hours);
            arbOraclePool = new OraclePool(
                _predictContractAddress(1),
                ARBITRUM_WETH_TOKEN,
                ARBITRUM_WSTETH_TOKEN,
                address(arbPriceOracle),
                0,
                address(this)
            );
            arbSender = new CustomSender(
                ARBITRUM_WETH_TOKEN,
                ARBITRUM_WETH_TOKEN,
                ARBITRUM_LINK_TOKEN,
                ARBITRUM_CCIP_ROUTER,
                address(arbOraclePool),
                address(this)
            );

            vm.label(ARBITRUM_CCIP_ROUTER, "ARB:CCIPRouter");
            vm.label(ARBITRUM_LINK_TOKEN, "ARB:LINK");
            vm.label(ARBITRUM_WETH_TOKEN, "ARB:WETH");
            vm.label(ARBITRUM_WSTETH_TOKEN, "ARB:WstETH");
            vm.label(ARBITRUM_WSTETH_STETH_DATAFEED, "ARB:WstETHEthDatafeed");
        }

        {
            vm.selectFork(opForkId);

            opPriceOracle = new PriceOracle(OPTIMISM_WSTETH_STETH_DATAFEED, false, 24 hours);
            opOraclePool = new OraclePool(
                _predictContractAddress(1),
                OPTIMISM_WETH_TOKEN,
                OPTIMISM_WSTETH_TOKEN,
                address(opPriceOracle),
                0,
                address(this)
            );
            opSender = new CustomSender(
                OPTIMISM_WETH_TOKEN,
                OPTIMISM_WETH_TOKEN,
                OPTIMISM_LINK_TOKEN,
                OPTIMISM_CCIP_ROUTER,
                address(opOraclePool),
                address(this)
            );

            vm.label(OPTIMISM_CCIP_ROUTER, "OP:CCIPRouter");
            vm.label(OPTIMISM_LINK_TOKEN, "OP:LINK");
            vm.label(OPTIMISM_WETH_TOKEN, "OP:WETH");
            vm.label(OPTIMISM_WSTETH_TOKEN, "OP:WstETH");
            vm.label(OPTIMISM_WSTETH_STETH_DATAFEED, "OP:WstETHEthDatafeed");
        }

        {
            vm.selectFork(baseForkId);

            basePriceOracle = new PriceOracle(BASE_WSTETH_STETH_DATAFEED, false, 24 hours);
            baseOraclePool = new OraclePool(
                _predictContractAddress(1),
                BASE_WETH_TOKEN,
                BASE_WSTETH_TOKEN,
                address(basePriceOracle),
                0,
                address(this)
            );
            baseSender = new CustomSender(
                BASE_WETH_TOKEN,
                BASE_WETH_TOKEN,
                BASE_LINK_TOKEN,
                BASE_CCIP_ROUTER,
                address(baseOraclePool),
                address(this)
            );

            vm.label(BASE_CCIP_ROUTER, "BASE:CCIPRouter");
            vm.label(BASE_LINK_TOKEN, "BASE:LINK");
            vm.label(BASE_WETH_TOKEN, "BASE:WETH");
            vm.label(BASE_WSTETH_TOKEN, "BASE:WstETH");
            vm.label(BASE_WSTETH_STETH_DATAFEED, "BASE:WstETHEthDatafeed");
        }

        {
            vm.selectFork(lineaForkId);

            lineaPriceOracle = new PriceOracle(LINEA_WSTETH_STETH_DATAFEED, false, 24 hours);
            lineaOraclePool = new OraclePool(
                _predictContractAddress(1),
                LINEA_WETH_TOKEN,
                LINEA_WSTETH_TOKEN,
                address(lineaPriceOracle),
                0,
                address(this)
            );
            lineaSender = new CustomSender(
                LINEA_WETH_TOKEN,
                LINEA_WETH_TOKEN,
                LINEA_LINK_TOKEN,
                LINEA_CCIP_ROUTER,
                address(lineaOraclePool),
                address(this)
            );

            vm.label(LINEA_CCIP_ROUTER, "LINEA:CCIPRouter");
            vm.label(LINEA_LINK_TOKEN, "LINEA:LINK");
            vm.label(LINEA_WETH_TOKEN, "LINEA:WETH");
            vm.label(LINEA_WSTETH_TOKEN, "LINEA:WstETH");
            vm.label(LINEA_WSTETH_STETH_DATAFEED, "LINEA:WstETHEthDatafeed");
        }

        // Setup
        {
            vm.selectFork(ethForkId);

            receiver.setSender(ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(address(arbSender)));
            receiver.setAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR, address(arbAdapter));

            receiver.setSender(OPTIMISM_CCIP_CHAIN_SELECTOR, abi.encode(address(opSender)));
            receiver.setAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR, address(opAdapter));

            receiver.setSender(BASE_CCIP_CHAIN_SELECTOR, abi.encode(address(baseSender)));
            receiver.setAdapter(BASE_CCIP_CHAIN_SELECTOR, address(baseAdapter));

            receiver.setSender(LINEA_CCIP_CHAIN_SELECTOR, abi.encode(address(lineaSender)));
            receiver.setAdapter(LINEA_CCIP_CHAIN_SELECTOR, address(lineaAdapter));
        }

        {
            vm.selectFork(arbForkId);

            arbSender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(receiver));
            arbSender.grantRole(arbSender.SYNC_ROLE(), address(this));
        }

        {
            vm.selectFork(opForkId);

            opSender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(receiver));
            opSender.grantRole(opSender.SYNC_ROLE(), address(this));
        }

        {
            vm.selectFork(baseForkId);

            baseSender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(receiver));
            baseSender.grantRole(baseSender.SYNC_ROLE(), address(this));
        }

        {
            vm.selectFork(lineaForkId);

            lineaSender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(receiver));
            lineaSender.grantRole(lineaSender.SYNC_ROLE(), address(this));
        }
    }

    function test_ArbFastStake() public {
        vm.selectFork(arbForkId);

        // Fund the oracle pool
        deal(ARBITRUM_WSTETH_TOKEN, address(arbOraclePool), 100e18);

        vm.deal(alice, 1e18);

        vm.startPrank(alice);
        {
            arbSender.fastStake{value: 1e18}(address(0), 1e18, 0.8e18);
            assertGt(IERC20(ARBITRUM_WSTETH_TOKEN).balanceOf(alice), 0.8e18, "test_ArbFastStake::1");
        }
        vm.stopPrank();

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeArbitrumL1toL2(0.01e18, 100_000, 45e9);

        uint256 amount = IERC20(ARBITRUM_WETH_TOKEN).balanceOf(address(arbOraclePool));
        arbSender.sync{value: 0.1e18}(ETHEREUM_CCIP_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);

        assertEq(IERC20(ARBITRUM_WETH_TOKEN).balanceOf(address(arbOraclePool)), 0, "test_ArbFastStake::2");

        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: ARBITRUM_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(arbSender)),
            data: FeeCodec.encodePackedDataMemory(address(arbOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_ArbFastStake::3");
    }

    function test_ArbSlowStake() public {
        vm.selectFork(arbForkId);

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeArbitrumL1toL2(0.01e18, 100_000, 45e9);

        uint256 amount = 1e18;

        (uint256 nativeFeeOtoD,) = FeeCodec.decodeFeeMemory(feeOtoD);
        (uint256 nativeFeeDtoO,) = FeeCodec.decodeFeeMemory(feeDtoO);

        uint256 nativeFee = amount + nativeFeeOtoD + nativeFeeDtoO;

        vm.deal(alice, nativeFee);

        vm.startPrank(alice);
        {
            arbSender.slowStake{value: nativeFee}(ETHEREUM_CCIP_CHAIN_SELECTOR, address(0), amount, feeOtoD, feeDtoO);
        }
        vm.stopPrank();

        assertLt(alice.balance, nativeFee, "test_ArbSlowStake::1");

        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: ARBITRUM_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(arbSender)),
            data: FeeCodec.encodePackedDataMemory(address(arbOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_ArbSlowStake::2");
    }

    function test_OpFastStake() public {
        vm.selectFork(opForkId);

        // Fund the oracle pool
        deal(OPTIMISM_WSTETH_TOKEN, address(opOraclePool), 100e18);

        vm.deal(alice, 1e18);

        vm.startPrank(alice);
        {
            opSender.fastStake{value: 1e18}(address(0), 1e18, 0.8e18);
            assertGt(IERC20(OPTIMISM_WSTETH_TOKEN).balanceOf(alice), 0.8e18, "test_OpFastStake::1");
        }
        vm.stopPrank();

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeOptimismL1toL2(100_000);

        uint256 amount = IERC20(OPTIMISM_WETH_TOKEN).balanceOf(address(opOraclePool));
        opSender.sync{value: 0.1e18}(ETHEREUM_CCIP_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);

        assertEq(IERC20(OPTIMISM_WETH_TOKEN).balanceOf(address(opOraclePool)), 0, "test_OpFastStake::2");

        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: OPTIMISM_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(opSender)),
            data: FeeCodec.encodePackedDataMemory(address(opOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_OpFastStake::3");
    }

    function test_OpSlowStake() public {
        vm.selectFork(opForkId);

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeOptimismL1toL2(100_000);

        uint256 amount = 1e18;

        (uint256 nativeFeeOtoD,) = FeeCodec.decodeFeeMemory(feeOtoD);
        (uint256 nativeFeeDtoO,) = FeeCodec.decodeFeeMemory(feeDtoO);

        uint256 nativeFee = amount + nativeFeeOtoD + nativeFeeDtoO;

        vm.deal(alice, nativeFee);

        vm.startPrank(alice);
        {
            opSender.slowStake{value: nativeFee}(ETHEREUM_CCIP_CHAIN_SELECTOR, address(0), amount, feeOtoD, feeDtoO);
        }
        vm.stopPrank();

        assertLt(alice.balance, nativeFee, "test_OpSlowStake::1");
        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: OPTIMISM_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(opSender)),
            data: FeeCodec.encodePackedDataMemory(address(opOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_OpSlowStake::2");
    }

    function test_BaseFastStake() public {
        vm.selectFork(baseForkId);

        // Fund the oracle pool
        deal(BASE_WSTETH_TOKEN, address(baseOraclePool), 100e18);

        vm.deal(alice, 1e18);

        vm.startPrank(alice);
        {
            baseSender.fastStake{value: 1e18}(address(0), 1e18, 0.8e18);
            assertGt(IERC20(BASE_WSTETH_TOKEN).balanceOf(alice), 0.8e18, "test_BaseFastStake::1");
        }
        vm.stopPrank();

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeBaseL1toL2(100_000);

        uint256 amount = IERC20(BASE_WETH_TOKEN).balanceOf(address(baseOraclePool));
        baseSender.sync{value: 0.1e18}(ETHEREUM_CCIP_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);

        assertEq(IERC20(BASE_WETH_TOKEN).balanceOf(address(baseOraclePool)), 0, "test_BaseFastStake::2");

        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: BASE_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(baseSender)),
            data: FeeCodec.encodePackedDataMemory(address(baseOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_BaseFastStake::3");
    }

    function test_BaseSlowStake() public {
        vm.selectFork(baseForkId);

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeBaseL1toL2(100_000);

        uint256 amount = 1e18;

        (uint256 nativeFeeOtoD,) = FeeCodec.decodeFeeMemory(feeOtoD);
        (uint256 nativeFeeDtoO,) = FeeCodec.decodeFeeMemory(feeDtoO);

        uint256 nativeFee = amount + nativeFeeOtoD + nativeFeeDtoO;

        vm.deal(alice, nativeFee);

        vm.startPrank(alice);
        {
            baseSender.slowStake{value: nativeFee}(ETHEREUM_CCIP_CHAIN_SELECTOR, address(0), amount, feeOtoD, feeDtoO);
        }
        vm.stopPrank();

        assertLt(alice.balance, nativeFee, "test_BaseSlowStake::1");
        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: BASE_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(baseSender)),
            data: FeeCodec.encodePackedDataMemory(address(baseOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_BaseSlowStake::2");
    }

    /// forge-config: default.evm_version = "cancun"
    function test_LineaFastStake() public {
        vm.selectFork(lineaForkId);

        // Fund the oracle pool
        deal(LINEA_WSTETH_TOKEN, address(lineaOraclePool), 100e18);

        vm.deal(alice, 1e18);

        vm.startPrank(alice);
        {
            lineaSender.fastStake{value: 1e18}(address(0), 1e18, 0.8e18);
            assertGt(IERC20(LINEA_WSTETH_TOKEN).balanceOf(alice), 0.8e18, "test_LineaFastStake::1");
        }
        vm.stopPrank();

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeLineaL1toL2();

        uint256 amount = IERC20(LINEA_WETH_TOKEN).balanceOf(address(lineaOraclePool));
        lineaSender.sync{value: 0.1e18}(ETHEREUM_CCIP_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);

        assertEq(IERC20(LINEA_WETH_TOKEN).balanceOf(address(lineaOraclePool)), 0, "test_LineaFastStake::2");

        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: LINEA_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(lineaSender)),
            data: FeeCodec.encodePackedDataMemory(address(lineaOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_LineaFastStake::3");
    }

    /// forge-config: default.evm_version = "cancun"
    function test_LineaSlowStake() public {
        vm.selectFork(lineaForkId);

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeLineaL1toL2();

        uint256 amount = 1e18;

        (uint256 nativeFeeOtoD,) = FeeCodec.decodeFeeMemory(feeOtoD);
        (uint256 nativeFeeDtoO,) = FeeCodec.decodeFeeMemory(feeDtoO);

        uint256 nativeFee = amount + nativeFeeOtoD + nativeFeeDtoO;

        vm.deal(alice, nativeFee);

        vm.startPrank(alice);
        {
            lineaSender.slowStake{value: nativeFee}(ETHEREUM_CCIP_CHAIN_SELECTOR, address(0), amount, feeOtoD, feeDtoO);
        }
        vm.stopPrank();

        assertLt(alice.balance, nativeFee, "test_LineaSlowStake::1");
        vm.selectFork(ethForkId);

        (uint256 nativeAmountBrigdged,) = FeeCodec.decodeFeeMemory(feeDtoO);
        nativeAmountBrigdged += amount;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: ETHEREUM_WETH_TOKEN, amount: nativeAmountBrigdged});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test"),
            sourceChainSelector: LINEA_CCIP_CHAIN_SELECTOR,
            sender: abi.encode(address(lineaSender)),
            data: FeeCodec.encodePackedDataMemory(address(lineaOraclePool), amount, feeDtoO),
            destTokenAmounts: tokenAmounts
        });

        deal(ETHEREUM_WETH_TOKEN, address(receiver), nativeAmountBrigdged);

        vm.prank(ETHEREUM_CCIP_ROUTER);
        receiver.ccipReceive(message);

        assertEq(receiver.getFailedMessageHash(message.messageId), 0, "test_LineaSlowStake::2");
    }

    function _predictContractAddress(uint256 deltaNonce) private view returns (address) {
        uint256 nonce = vm.getNonce(address(this)) + deltaNonce;
        return vm.computeCreateAddress(address(this), nonce);
    }

    receive() external payable {}
}
