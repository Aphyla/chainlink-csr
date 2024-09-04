// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../../contracts/senders/CustomSender.sol";
import "../../contracts/utils/PriceOracle.sol";
import "../../contracts/utils/OraclePool.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockWNative.sol";
import "../mocks/MockCCIPRouter.sol";
import "../mocks/MockDataFeed.sol";

contract CustomSenderStakedTokenTest is Test {
    CustomSender public sender;
    PriceOracle public priceOracle;
    OraclePool public oraclePool;

    MockDataFeed public dataFeed;
    MockCCIPRouter public ccipRouter;
    MockERC20 public link;
    MockERC20 public token;
    MockERC20 public stakedToken;
    MockWNative public wnative;

    uint128 public constant LINK_FEE = 1e18;
    uint128 public constant NATIVE_FEE = 0.01e18;

    function setUp() public {
        link = new MockERC20("Link", "LINK", 18);
        ccipRouter = new MockCCIPRouter(address(link), LINK_FEE, NATIVE_FEE);
        dataFeed = new MockDataFeed(18);
        priceOracle = new PriceOracle(address(dataFeed), false, 1 hours, address(this));

        token = new MockERC20("Token", "TK", 18);
        stakedToken = new MockERC20("StakedToken", "STK", 18);

        wnative = new MockWNative();

        oraclePool = new OraclePool(
            _predictContractAddress(1),
            address(stakedToken),
            address(token),
            address(priceOracle),
            0.05e18,
            address(this)
        );

        sender = new CustomSender(
            address(stakedToken),
            address(wnative),
            address(link),
            address(ccipRouter),
            address(oraclePool),
            address(this)
        );
    }

    function test_Constructor() public {
        sender = new CustomSender(
            address(stakedToken),
            address(wnative),
            address(link),
            address(ccipRouter),
            address(oraclePool),
            address(this)
        ); // to fix coverage

        assertEq(sender.TOKEN(), address(stakedToken), "test_Constructor::1");
        assertEq(sender.WNATIVE(), address(wnative), "test_Constructor::2");
        assertEq(sender.LINK_TOKEN(), address(link), "test_Constructor::3");
        assertEq(sender.CCIP_ROUTER(), address(ccipRouter), "test_Constructor::4");
        assertEq(sender.getOraclePool(), address(oraclePool), "test_Constructor::5");
        assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), address(this)), true, "test_Constructor::6");
    }

    function test_Fuzz_FastStakeStakedToken(uint256 price, uint256 amountIn) public {
        price = bound(price, 0.001e18, 100e18);
        amountIn = bound(amountIn, 1, 100e18);

        dataFeed.set(int256(price), 1, block.timestamp, block.timestamp, 1);

        uint256 feeAmountIn = amountIn * oraclePool.getFee() / 1e18;
        uint256 amountOut = (amountIn - feeAmountIn) * 1e18 / price;

        token.mint(address(oraclePool), amountOut);

        stakedToken.mint(address(this), amountIn);
        stakedToken.approve(address(sender), amountIn);

        uint256 balance = address(this).balance;

        sender.fastStake(address(stakedToken), amountIn, amountOut);

        assertEq(stakedToken.balanceOf(address(this)), 0, "test_Fuzz_FastStakeStakedToken::1");
        assertEq(stakedToken.balanceOf(address(oraclePool)), amountIn, "test_Fuzz_FastStakeStakedToken::2");
        assertEq(token.balanceOf(address(this)), amountOut, "test_Fuzz_FastStakeStakedToken::3");
        assertEq(token.balanceOf(address(oraclePool)), 0, "test_Fuzz_FastStakeStakedToken::4");
        assertEq(address(this).balance, balance, "test_Fuzz_FastStakeStakedToken::5");
    }

    struct Amounts {
        uint256 native;
        uint256 wnative;
        uint256 link;
    }

    function test_Fuzz_SlowStakeStakedToken(
        bytes memory receiver,
        uint64 destChainSelector,
        uint256 amountIn,
        bool payInLinkOtoD,
        uint32 gasLimitOtoD,
        uint128 feeAmountDtoO,
        bool payInLinkDtoO
    ) public {
        vm.assume(receiver.length > 0);

        amountIn = bound(amountIn, 1, 100e18);
        feeAmountDtoO = uint128(bound(feeAmountDtoO, 0, 10e18));
        gasLimitOtoD = uint32(bound(gasLimitOtoD, sender.MIN_PROCESS_MESSAGE_GAS(), type(uint32).max));

        sender.setReceiver(destChainSelector, receiver);

        stakedToken.mint(address(this), amountIn);
        stakedToken.approve(address(sender), amountIn);

        bytes memory feeOtoD = FeeCodec.encodeCCIP(payInLinkOtoD ? LINK_FEE : NATIVE_FEE, payInLinkOtoD, gasLimitOtoD);
        bytes memory feeDtoO = abi.encodePacked(feeAmountDtoO, payInLinkDtoO);

        Amounts memory amounts = Amounts({
            native: (payInLinkOtoD ? 0 : NATIVE_FEE) + (payInLinkDtoO ? 0 : feeAmountDtoO),
            wnative: (payInLinkDtoO ? 0 : feeAmountDtoO),
            link: (payInLinkOtoD ? LINK_FEE : 0) + (payInLinkDtoO ? feeAmountDtoO : 0)
        });

        if (amounts.link > 0) {
            link.mint(address(this), amounts.link);
            link.approve(address(sender), amounts.link);
        }

        Client.EVMTokenAmount[] memory tokenAmounts;

        if (feeAmountDtoO == 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(stakedToken), amount: amountIn});
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](2);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(stakedToken), amount: amountIn});

            tokenAmounts[1] =
                Client.EVMTokenAmount({token: payInLinkDtoO ? address(link) : address(wnative), amount: feeAmountDtoO});
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: FeeCodec.encodePackedDataMemory(address(this), amountIn, feeDtoO),
            tokenAmounts: tokenAmounts,
            feeToken: payInLinkOtoD ? address(link) : address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimitOtoD}))
        });

        uint256 balance = address(this).balance;

        sender.slowStake{value: 1e18 + amounts.native}(
            destChainSelector, address(stakedToken), amountIn, feeOtoD, feeDtoO
        );

        assertEq(stakedToken.balanceOf(address(this)), 0, "test_Fuzz_SlowStakeStakedToken::1");
        assertEq(stakedToken.balanceOf(address(oraclePool)), 0, "test_Fuzz_SlowStakeStakedToken::2");
        assertEq(stakedToken.balanceOf(address(ccipRouter)), amountIn, "test_Fuzz_SlowStakeStakedToken::3");
        assertEq(wnative.balanceOf(address(this)), 0, "test_Fuzz_SlowStakeStakedToken::4");
        assertEq(wnative.balanceOf(address(oraclePool)), 0, "test_Fuzz_SlowStakeStakedToken::5");
        assertEq(wnative.balanceOf(address(ccipRouter)), amounts.wnative, "test_Fuzz_SlowStakeStakedToken::6");
        assertEq(token.balanceOf(address(this)), 0, "test_Fuzz_SlowStakeStakedToken::7");
        assertEq(token.balanceOf(address(oraclePool)), 0, "test_Fuzz_SlowStakeStakedToken::8");
        assertEq(token.balanceOf(address(ccipRouter)), 0, "test_Fuzz_SlowStakeStakedToken::9");
        assertEq(link.balanceOf(address(this)), 0, "test_Fuzz_SlowStakeStakedToken::10");
        assertEq(link.balanceOf(address(oraclePool)), 0, "test_Fuzz_SlowStakeStakedToken::11");
        assertEq(link.balanceOf(address(ccipRouter)), amounts.link, "test_Fuzz_SlowStakeStakedToken::12");
        assertEq(address(this).balance, balance - amounts.native, "test_Fuzz_SlowStakeStakedToken::13");
        assertEq(address(oraclePool).balance, 0, "test_Fuzz_SlowStakeStakedToken::14");
        assertEq(address(ccipRouter).balance, payInLinkOtoD ? 0 : NATIVE_FEE, "test_Fuzz_SlowStakeStakedToken::15");

        assertEq(ccipRouter.value(), (payInLinkOtoD ? 0 : NATIVE_FEE), "test_Fuzz_SlowStakeStakedToken::16");
        assertEq(ccipRouter.data(), abi.encode(destChainSelector, message), "test_Fuzz_SlowStakeStakedToken::17");
    }

    function test_Fuzz_SyncStakedToken(
        bytes memory receiver,
        uint64 destChainSelector,
        uint256 amountToSync,
        bool payInLinkOtoD,
        uint32 gasLimitOtoD,
        uint128 feeAmountDtoO,
        bool payInLinkDtoO
    ) public {
        vm.assume(receiver.length > 0);

        amountToSync = bound(amountToSync, 1, 100e18);
        feeAmountDtoO = uint128(bound(feeAmountDtoO, 0, 10e18));
        gasLimitOtoD = uint32(bound(gasLimitOtoD, sender.MIN_PROCESS_MESSAGE_GAS(), type(uint32).max));

        sender.setReceiver(destChainSelector, receiver);
        sender.grantRole(sender.SYNC_ROLE(), address(this));

        bytes memory feeOtoD = FeeCodec.encodeCCIP(payInLinkOtoD ? LINK_FEE : NATIVE_FEE, payInLinkOtoD, gasLimitOtoD);
        bytes memory feeDtoO = abi.encodePacked(feeAmountDtoO, payInLinkDtoO);

        Amounts memory amounts = Amounts({
            native: (payInLinkOtoD ? 0 : NATIVE_FEE) + (payInLinkDtoO ? 0 : feeAmountDtoO),
            wnative: (payInLinkDtoO ? 0 : feeAmountDtoO),
            link: (payInLinkOtoD ? LINK_FEE : 0) + (payInLinkDtoO ? feeAmountDtoO : 0)
        });

        if (amounts.link > 0) {
            link.mint(address(this), amounts.link);
            link.approve(address(sender), amounts.link);
        }

        Client.EVMTokenAmount[] memory tokenAmounts;

        if (feeAmountDtoO == 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(stakedToken), amount: amountToSync});
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](2);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(stakedToken), amount: amountToSync});

            tokenAmounts[1] =
                Client.EVMTokenAmount({token: payInLinkDtoO ? address(link) : address(wnative), amount: feeAmountDtoO});
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: FeeCodec.encodePackedDataMemory(address(oraclePool), amountToSync, feeDtoO),
            tokenAmounts: tokenAmounts,
            feeToken: payInLinkOtoD ? address(link) : address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimitOtoD}))
        });

        stakedToken.mint(address(oraclePool), amountToSync);

        uint256 balance = address(this).balance;

        sender.sync{value: 1e18 + amounts.native}(destChainSelector, amountToSync, feeOtoD, feeDtoO);

        assertEq(stakedToken.balanceOf(address(this)), 0, "test_Fuzz_SyncStakedToken::1");
        assertEq(stakedToken.balanceOf(address(oraclePool)), 0, "test_Fuzz_SyncStakedToken::2");
        assertEq(stakedToken.balanceOf(address(ccipRouter)), amountToSync, "test_Fuzz_SyncStakedToken::3");
        assertEq(wnative.balanceOf(address(this)), 0, "test_Fuzz_SyncStakedToken::4");
        assertEq(wnative.balanceOf(address(oraclePool)), 0, "test_Fuzz_SyncStakedToken::5");
        assertEq(wnative.balanceOf(address(ccipRouter)), amounts.wnative, "test_Fuzz_SyncStakedToken::6");
        assertEq(token.balanceOf(address(this)), 0, "test_Fuzz_SyncStakedToken::7");
        assertEq(token.balanceOf(address(oraclePool)), 0, "test_Fuzz_SyncStakedToken::8");
        assertEq(token.balanceOf(address(ccipRouter)), 0, "test_Fuzz_SyncStakedToken::9");
        assertEq(link.balanceOf(address(this)), 0, "test_Fuzz_SyncStakedToken::10");
        assertEq(link.balanceOf(address(oraclePool)), 0, "test_Fuzz_SyncStakedToken::11");
        assertEq(link.balanceOf(address(ccipRouter)), amounts.link, "test_Fuzz_SyncStakedToken::12");
        assertEq(address(this).balance, balance - amounts.native, "test_Fuzz_SyncStakedToken::13");
        assertEq(address(oraclePool).balance, 0, "test_Fuzz_SyncStakedToken::14");
        assertEq(address(ccipRouter).balance, payInLinkOtoD ? 0 : NATIVE_FEE, "test_Fuzz_SyncStakedToken::15");

        assertEq(ccipRouter.value(), (payInLinkOtoD ? 0 : NATIVE_FEE), "test_Fuzz_SyncStakedToken::16");
        assertEq(ccipRouter.data(), abi.encode(destChainSelector, message), "test_Fuzz_SyncStakedToken::17");
    }

    receive() external payable {}

    function _predictContractAddress(uint256 deltaNonce) private view returns (address) {
        uint256 nonce = vm.getNonce(address(this)) + deltaNonce;
        return vm.computeCreateAddress(address(this), nonce);
    }
}
