// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import "../../script/eigenpie/EigenpieParameters.sol";
import "../../contracts/senders/CustomSender.sol";
import "../../contracts/receivers/EigenpieCustomReceiver.sol";
import "../../contracts/adapters/CCIPAdapter.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/utils/PriceOracle.sol";

// Those tests needs to be run with the shangai evm version, orelse they will fail, use:
// `forge test --match-contract EIGENPIE --evm-version shanghai`
contract shanghai_CCIPIntegrationEIGENPIETest is Test, EigenpieParameters {
    uint256 ethForkId;
    EigenpieCustomReceiver receiver;
    CCIPAdapter ccipAdapter;

    uint256 arbForkId;
    CustomSender arbSender;
    OraclePool arbOraclePool;
    PriceOracle arbPriceOracle;

    address alice = makeAddr("alice");

    function setUp() public {
        ethForkId = vm.createFork(vm.rpcUrl("ethereum"), ETHEREUM_FORK_BLOCK);
        arbForkId = vm.createFork(vm.rpcUrl("arbitrum"), ARBITRUM_FORK_BLOCK);

        // Deployments
        {
            vm.selectFork(ethForkId);
            receiver = new EigenpieCustomReceiver(
                ETHEREUM_EGETH_TOKEN, ETHEREUM_EGETH_STAKING, ETHEREUM_WETH_TOKEN, ETHEREUM_CCIP_ROUTER, address(this)
            );

            ccipAdapter =
                new CCIPAdapter(ETHEREUM_EGETH_TOKEN, ETHEREUM_CCIP_ROUTER, ETHEREUM_LINK_TOKEN, address(receiver));

            vm.label(ETHEREUM_CCIP_ROUTER, "ETH:CCIPRouter");
            vm.label(ETHEREUM_LINK_TOKEN, "ETH:LINK");
            vm.label(ETHEREUM_WETH_TOKEN, "ETH:WETH");
            vm.label(ETHEREUM_EGETH_TOKEN, "ETH:EGETH");
        }

        {
            vm.selectFork(arbForkId);

            arbPriceOracle = new PriceOracle(ARBITRUM_EGETH_ETH_DATAFEED, false, 24 hours, address(this));
            arbOraclePool = new OraclePool(
                _predictContractAddress(1),
                ARBITRUM_WETH_TOKEN,
                ARBITRUM_EGETH_TOKEN,
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
            vm.label(ARBITRUM_EGETH_TOKEN, "ARB:EGETH");
            vm.label(ARBITRUM_EGETH_ETH_DATAFEED, "ARB:EGETHEthDatafeed");
        }

        // Setup
        {
            vm.selectFork(ethForkId);

            receiver.setSender(ARBITRUM_CCIP_CHAIN_SELECTOR, abi.encode(address(arbSender)));
            receiver.setAdapter(ARBITRUM_CCIP_CHAIN_SELECTOR, address(ccipAdapter));
        }

        {
            vm.selectFork(arbForkId);

            arbSender.setReceiver(ETHEREUM_CCIP_CHAIN_SELECTOR, abi.encode(receiver));
            arbSender.grantRole(arbSender.SYNC_ROLE(), address(this));
        }
    }

    function test_ArbFastStake() public {
        vm.selectFork(arbForkId);

        // Fund the oracle pool
        deal(ARBITRUM_EGETH_TOKEN, address(arbOraclePool), 100e18);

        vm.deal(alice, 1e18);

        vm.startPrank(alice);
        {
            arbSender.fastStake{value: 1e18}(address(0), 1e18, 0.8e18);
            assertGt(IERC20(ARBITRUM_EGETH_TOKEN).balanceOf(alice), 0.8e18, "test_ArbFastStake::1");
        }
        vm.stopPrank();

        bytes memory feeOtoD = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);
        bytes memory feeDtoO = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);

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
        bytes memory feeDtoO = FeeCodec.encodeCCIP(0.1e18, false, 1_000_000);

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

    function _predictContractAddress(uint256 deltaNonce) private view returns (address) {
        uint256 nonce = vm.getNonce(address(this)) + deltaNonce;
        return vm.computeCreateAddress(address(this), nonce);
    }

    receive() external payable {}
}
