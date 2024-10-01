// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import "../../script/frax/FraxParameters.sol";
import "../../contracts/senders/CustomSender.sol";
import "../../contracts/receivers/FraxCustomReceiver.sol";
import "../../contracts/adapters/FraxFerryAdapterL1toL2.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";

contract fork_CCIPIntegrationFRAXTest is Test, FraxParameters {
    uint256 ethForkId;
    FraxCustomReceiver receiver;
    FraxFerryAdapterL1toL2 arbAdapter;
    FraxFerryAdapterL1toL2 opAdapter;

    uint256 arbForkId;
    CustomSender arbSender;
    OraclePool arbOraclePool;
    PriceOracle arbPriceOracle;

    uint256 opForkId;
    CustomSender opSender;
    OraclePool opOraclePool;
    PriceOracle opPriceOracle;

    address alice = makeAddr("alice");

    function setUp() public {
        ethForkId = vm.createFork(vm.rpcUrl("mainnet"), ETHEREUM_FORK_BLOCK);
        arbForkId = vm.createFork(vm.rpcUrl("arbitrum"), ARBITRUM_FORK_BLOCK);
        opForkId = vm.createFork(vm.rpcUrl("optimism"), OPTIMISM_FORK_BLOCK);

        // Deployments
        {
            vm.selectFork(ethForkId);
            receiver = new FraxCustomReceiver(
                ETHEREUM_SFRXETH_TOKEN, ETHEREUM_FRXETH_MINTER, ETHEREUM_WETH_TOKEN, ETHEREUM_CCIP_ROUTER, address(this)
            );

            arbAdapter =
                new FraxFerryAdapterL1toL2(ETHEREUM_TO_ARBITRUM_FRAX_FERRY, ETHEREUM_SFRXETH_TOKEN, address(receiver));
            opAdapter =
                new FraxFerryAdapterL1toL2(ETHEREUM_TO_OPTIMISM_FRAX_FERRY, ETHEREUM_SFRXETH_TOKEN, address(receiver));

            vm.label(ETHEREUM_CCIP_ROUTER, "ETH:CCIPRouter");
            vm.label(ETHEREUM_LINK_TOKEN, "ETH:LINK");
            vm.label(ETHEREUM_WETH_TOKEN, "ETH:WETH");
            vm.label(ETHEREUM_SFRXETH_TOKEN, "ETH:SFRXETH");
            vm.label(ETHEREUM_FRXETH_MINTER, "ETH:FRXETHMinter");
            vm.label(ETHEREUM_TO_ARBITRUM_FRAX_FERRY, "ETH:ToArbitrumFraxFerry");
            vm.label(ETHEREUM_TO_OPTIMISM_FRAX_FERRY, "ETH:ToOptimismFraxFerry");
            vm.label(address(arbAdapter), "ETH:ArbAdapter");
            vm.label(address(opAdapter), "ETH:OpAdapter");
        }

        {
            vm.selectFork(arbForkId);

            arbPriceOracle = new PriceOracle(ARBITRUM_SFRXETH_FRXETH_DATAFEED, false, 24 hours);
            arbOraclePool = new OraclePool(
                _predictContractAddress(1),
                ARBITRUM_WETH_TOKEN,
                ARBITRUM_SFRXETH_TOKEN,
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
            vm.label(ARBITRUM_SFRXETH_TOKEN, "ARB:SFRXETH");
            vm.label(ARBITRUM_SFRXETH_FRXETH_DATAFEED, "ARB:SFRXETHEthDatafeed");
        }

        {
            vm.selectFork(opForkId);

            opPriceOracle = new PriceOracle(OPTIMISM_SFRXETH_FRXETH_DATAFEED, false, 24 hours);
            opOraclePool = new OraclePool(
                _predictContractAddress(1),
                OPTIMISM_WETH_TOKEN,
                OPTIMISM_SFRXETH_TOKEN,
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
            vm.label(OPTIMISM_SFRXETH_TOKEN, "OP:SFRXETH");
            vm.label(OPTIMISM_SFRXETH_FRXETH_DATAFEED, "OP:SFRXETHEthDatafeed");
        }

        // Setup
        {
            vm.selectFork(ethForkId);

            receiver.setSender(ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(address(arbSender)));
            receiver.setAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR, address(arbAdapter));

            receiver.setSender(OPTIMISM_CCIP_CHAIN_SELECTOR, abi.encode(address(opSender)));
            receiver.setAdapter(OPTIMISM_CCIP_CHAIN_SELECTOR, address(opAdapter));
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
    }

    function test_ArbFastStake() public {
        vm.selectFork(arbForkId);

        // Fund the oracle pool
        deal(ARBITRUM_SFRXETH_TOKEN, address(arbOraclePool), 100e18);

        vm.deal(alice, 1e18);

        vm.startPrank(alice);
        {
            arbSender.fastStake{value: 1e18}(address(0), 1e18, 0.8e18);
            assertGt(IERC20(ARBITRUM_SFRXETH_TOKEN).balanceOf(alice), 0.8e18, "test_ArbFastStake::1");
        }
        vm.stopPrank();

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeFraxFerryL1toL2();

        uint256 amount = IERC20(ARBITRUM_WETH_TOKEN).balanceOf(address(arbOraclePool));
        arbSender.sync{value: 0.2e18}(ETHEREUM_CCIP_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);

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
        bytes memory feeDtoO = FeeCodec.encodeFraxFerryL1toL2();

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
        deal(OPTIMISM_SFRXETH_TOKEN, address(opOraclePool), 100e18);

        vm.deal(alice, 1e18);

        vm.startPrank(alice);
        {
            opSender.fastStake{value: 1e18}(address(0), 1e18, 0.8e18);
            assertGt(IERC20(OPTIMISM_SFRXETH_TOKEN).balanceOf(alice), 0.8e18, "test_OpFastStake::1");
        }
        vm.stopPrank();

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeFraxFerryL1toL2();

        uint256 amount = IERC20(OPTIMISM_WETH_TOKEN).balanceOf(address(opOraclePool));
        opSender.sync{value: 0.2e18}(ETHEREUM_CCIP_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);

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
        bytes memory feeDtoO = FeeCodec.encodeFraxFerryL1toL2();

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

    function _predictContractAddress(uint256 deltaNonce) private view returns (address) {
        uint256 nonce = vm.getNonce(address(this)) + deltaNonce;
        return vm.computeCreateAddress(address(this), nonce);
    }

    receive() external payable {}
}
