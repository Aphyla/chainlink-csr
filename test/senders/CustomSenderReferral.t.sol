// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../../contracts/senders/CustomSenderReferral.sol";
import "../../contracts/senders/CustomSender.sol";
import "../../contracts/utils/PriceOracle.sol";
import "../../contracts/utils/OraclePool.sol";
import "../../contracts/ccip/CCIPSenderUpgradeable.sol";
import "../../contracts/ccip/CCIPBaseUpgradeable.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockWNative.sol";
import "../mocks/MockCCIPRouter.sol";
import "../mocks/MockDataFeed.sol";

contract CustomSenderReferralTest is Test {
    CustomSenderReferral public sender;
    PriceOracle public priceOracle;
    OraclePool public oraclePool;

    MockDataFeed public dataFeed;
    MockCCIPRouter public ccipRouter;
    MockERC20 public link;
    MockERC20 public token;
    MockWNative public wnative;

    uint128 public constant LINK_FEE = 1e18;
    uint128 public constant NATIVE_FEE = 0.01e18;

    event Referral(address indexed user, address indexed referral, uint256 amountOut);

    function setUp() public {
        link = new MockERC20("Link", "LINK", 18);
        ccipRouter = new MockCCIPRouter(address(link), LINK_FEE, NATIVE_FEE);
        dataFeed = new MockDataFeed(18);
        priceOracle = new PriceOracle(address(dataFeed), false, 1 hours);

        token = new MockERC20("Token", "TK", 18);
        wnative = new MockWNative();

        oraclePool = new OraclePool(
            _predictContractAddress(1), address(wnative), address(token), address(priceOracle), 0.05e18, address(this)
        );
        sender = new CustomSenderReferral(
            address(wnative), address(wnative), address(link), address(ccipRouter), address(oraclePool), address(this)
        );
    }

    function test_Constructor() public {
        sender = new CustomSenderReferral(
            address(wnative), address(wnative), address(link), address(ccipRouter), address(oraclePool), address(this)
        ); // to fix coverage

        assertEq(sender.TOKEN(), address(wnative), "test_Constructor::1");
        assertEq(sender.WNATIVE(), address(wnative), "test_Constructor::2");
        assertEq(sender.LINK_TOKEN(), address(link), "test_Constructor::3");
        assertEq(sender.CCIP_ROUTER(), address(ccipRouter), "test_Constructor::4");
        assertEq(sender.getOraclePool(), address(oraclePool), "test_Constructor::5");
        assertEq(sender.hasRole(sender.DEFAULT_ADMIN_ROLE(), address(this)), true, "test_Constructor::6");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(ICustomSender.CustomSenderInvalidParameters.selector);
        sender = new CustomSenderReferral(
            address(0), address(wnative), address(link), address(ccipRouter), address(oraclePool), address(this)
        );

        vm.expectRevert(ICustomSender.CustomSenderInvalidParameters.selector);
        sender = new CustomSenderReferral(
            address(wnative), address(0), address(link), address(ccipRouter), address(oraclePool), address(this)
        );

        vm.expectRevert(ICCIPSenderUpgradeable.CCIPSenderInvalidParameters.selector);
        sender = new CustomSenderReferral(
            address(wnative), address(wnative), address(0), address(ccipRouter), address(oraclePool), address(this)
        );

        vm.expectRevert(ICCIPBaseUpgradeable.CCIPBaseInvalidParameters.selector);
        sender = new CustomSenderReferral(
            address(wnative), address(wnative), address(link), address(0), address(oraclePool), address(this)
        );

        // Should not revert, we allow the oracle pool to be set to address(0) to disable fast stake
        sender = new CustomSenderReferral(
            address(wnative), address(wnative), address(link), address(ccipRouter), address(0), address(this)
        );

        vm.expectRevert(ICustomSender.CustomSenderInvalidParameters.selector);
        sender = new CustomSenderReferral(
            address(wnative), address(wnative), address(link), address(ccipRouter), address(oraclePool), address(0)
        );
    }

    function test_Revert_Initialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sender.initialize(address(0), address(0));
    }

    function test_Fuzz_FastStakeReferralWNative(uint256 price, uint256 amountIn, address referral) public {
        price = bound(price, 0.001e18, 100e18);
        amountIn = bound(amountIn, 1, 100e18);

        dataFeed.set(int256(price), 1, block.timestamp, block.timestamp, 1);

        uint256 feeAmountIn = amountIn * oraclePool.getFee() / 1e18;
        uint256 amountOut = (amountIn - feeAmountIn) * 1e18 / price;

        token.mint(address(oraclePool), amountOut);
        wnative.deposit{value: amountIn}();

        wnative.approve(address(sender), amountIn);

        uint256 balance = address(this).balance;

        vm.expectEmit(true, true, true, true);
        emit Referral(address(this), referral, amountOut);

        sender.fastStakeReferral{value: 1e18}(address(wnative), amountIn, amountOut, referral);

        assertEq(wnative.balanceOf(address(this)), 0, "test_Fuzz_FastStakeReferralWNative::1");
        assertEq(wnative.balanceOf(address(oraclePool)), amountIn, "test_Fuzz_FastStakeReferralWNative::2");
        assertEq(token.balanceOf(address(this)), amountOut, "test_Fuzz_FastStakeReferralWNative::3");
        assertEq(token.balanceOf(address(oraclePool)), 0, "test_Fuzz_FastStakeReferralWNative::4");
        assertEq(address(this).balance, balance, "test_Fuzz_FastStakeReferralWNative::5");
    }

    function test_Fuzz_FastStakeReferralNative(uint256 price, uint256 amountIn, address referral) public {
        price = bound(price, 0.001e18, 100e18);
        amountIn = bound(amountIn, 1, 100e18);

        dataFeed.set(int256(price), 1, block.timestamp, block.timestamp, 1);

        uint256 feeAmountIn = amountIn * oraclePool.getFee() / 1e18;
        uint256 amountOut = (amountIn - feeAmountIn) * 1e18 / price;

        token.mint(address(oraclePool), amountOut);

        uint256 balance = address(this).balance;

        vm.expectEmit(true, true, true, true);
        emit Referral(address(this), referral, amountOut);

        sender.fastStakeReferral{value: 2 * amountIn}(address(0), amountIn, amountOut, referral);

        assertEq(wnative.balanceOf(address(this)), 0, "test_Fuzz_FastStakeReferralNative::1");
        assertEq(wnative.balanceOf(address(oraclePool)), amountIn, "test_Fuzz_FastStakeReferralNative::2");
        assertEq(token.balanceOf(address(this)), amountOut, "test_Fuzz_FastStakeReferralNative::3");
        assertEq(token.balanceOf(address(oraclePool)), 0, "test_Fuzz_FastStakeReferralNative::4");
        assertEq(address(this).balance, balance - amountIn, "test_Fuzz_FastStakeReferralNative::5");
    }

    function test_Fuzz_Revert_FastStakeReferral(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, type(uint256).max);

        dataFeed.set(1e18, 1, block.timestamp, block.timestamp, 1);

        sender.setOraclePool(address(0));

        vm.expectRevert(ICustomSender.CustomSenderOraclePoolNotSet.selector);
        sender.fastStakeReferral(address(0), amountIn, 0, address(0));

        sender.setOraclePool(address(oraclePool));

        address badToken = address(new MockERC20("BadToken", "BAD", 18));

        vm.expectRevert(ICustomSender.CustomSenderInvalidToken.selector);
        sender.fastStakeReferral(badToken, 1, 0, address(0));

        vm.expectRevert(ICustomSender.CustomSenderZeroAmount.selector);
        sender.fastStakeReferral(address(0), 0, 0, address(0));

        vm.expectRevert(
            abi.encodeWithSelector(ICustomSender.CustomSenderInsufficientNativeBalance.selector, amountIn, 0)
        );
        sender.fastStakeReferral(address(0), amountIn, 0, address(0));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, sender, 0, amountIn));
        sender.fastStakeReferral(address(wnative), amountIn, 0, address(0));

        wnative.approve(address(sender), amountIn);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, amountIn)
        );
        sender.fastStakeReferral(address(wnative), amountIn, 0, address(0));

        sender = new CustomSenderReferral(
            address(badToken), address(wnative), address(link), address(ccipRouter), address(oraclePool), address(this)
        );

        vm.expectRevert(ICustomSender.CustomSenderInvalidToken.selector);
        sender.fastStakeReferral(address(0), 1, 0, address(0));
    }

    struct Amounts {
        uint256 native;
        uint256 wnative;
        uint256 link;
    }

    function test_Fuzz_Sync(
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
            wnative: amountToSync + (payInLinkDtoO ? 0 : feeAmountDtoO),
            link: (payInLinkOtoD ? LINK_FEE : 0) + (payInLinkDtoO ? feeAmountDtoO : 0)
        });

        if (amounts.link > 0) {
            link.mint(address(this), amounts.link);
            link.approve(address(sender), amounts.link);
        }

        Client.EVMTokenAmount[] memory tokenAmounts;

        if (!payInLinkDtoO || feeAmountDtoO == 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(wnative), amount: amounts.wnative});
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](2);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(wnative), amount: amounts.wnative});
            tokenAmounts[1] = Client.EVMTokenAmount({token: address(link), amount: feeAmountDtoO});
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: FeeCodec.encodePackedDataMemory(address(oraclePool), amountToSync, feeDtoO),
            tokenAmounts: tokenAmounts,
            feeToken: payInLinkOtoD ? address(link) : address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimitOtoD}))
        });

        wnative.deposit{value: amountToSync}();
        wnative.transfer(address(oraclePool), amountToSync);

        uint256 balance = address(this).balance;

        sender.sync{value: 1e18 + amounts.native}(destChainSelector, amountToSync, feeOtoD, feeDtoO);

        assertEq(wnative.balanceOf(address(this)), 0, "test_Fuzz_Sync::1");
        assertEq(wnative.balanceOf(address(oraclePool)), 0, "test_Fuzz_Sync::2");
        assertEq(wnative.balanceOf(address(ccipRouter)), amounts.wnative, "test_Fuzz_Sync::3");
        assertEq(token.balanceOf(address(this)), 0, "test_Fuzz_Sync::4");
        assertEq(token.balanceOf(address(oraclePool)), 0, "test_Fuzz_Sync::5");
        assertEq(token.balanceOf(address(ccipRouter)), 0, "test_Fuzz_Sync::6");
        assertEq(link.balanceOf(address(this)), 0, "test_Fuzz_Sync::7");
        assertEq(link.balanceOf(address(oraclePool)), 0, "test_Fuzz_Sync::8");
        assertEq(link.balanceOf(address(ccipRouter)), amounts.link, "test_Fuzz_Sync::9");
        assertEq(address(this).balance, balance - amounts.native, "test_Fuzz_Sync::10");
        assertEq(address(oraclePool).balance, 0, "test_Fuzz_Sync::11");
        assertEq(address(ccipRouter).balance, payInLinkOtoD ? 0 : NATIVE_FEE, "test_Fuzz_Sync::12");

        assertEq(ccipRouter.value(), (payInLinkOtoD ? 0 : NATIVE_FEE), "test_Fuzz_Sync::13");
        assertEq(ccipRouter.data(), abi.encode(destChainSelector, message), "test_Fuzz_Sync::14");
    }

    function test_Fuzz_Revert_Sync(uint256 amountToSync) public {
        amountToSync = bound(amountToSync, 1, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), sender.SYNC_ROLE()
            )
        );
        sender.sync(0, 0, new bytes(0), new bytes(0));

        sender.grantRole(sender.SYNC_ROLE(), address(this));

        sender.setOraclePool(address(0));

        vm.expectRevert(ICustomSender.CustomSenderZeroAmount.selector);
        sender.sync(0, 0, new bytes(0), new bytes(0));

        vm.expectRevert(ICustomSender.CustomSenderOraclePoolNotSet.selector);
        sender.sync(0, 1, new bytes(0), new bytes(0));

        sender.setOraclePool(address(oraclePool));

        vm.expectRevert(
            abi.encodeWithSelector(IOraclePool.OraclePoolInsufficientToken.selector, address(wnative), amountToSync, 0)
        );
        sender.sync(0, amountToSync, new bytes(0), new bytes(0));

        amountToSync = bound(amountToSync, 1, 100e18);

        wnative.deposit{value: amountToSync}();
        wnative.transfer(address(oraclePool), amountToSync);

        wnative.deposit{value: amountToSync}();

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, 0, 17));
        sender.sync(0, amountToSync, new bytes(0), new bytes(0));

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, 0, 21));
        sender.sync(0, amountToSync, new bytes(0), new bytes(17));

        vm.expectRevert(ICustomSender.CustomSenderInsufficientGas.selector);
        sender.sync(0, amountToSync, new bytes(21), new bytes(17));

        vm.expectRevert(abi.encodeWithSelector(ICustomSender.CustomSenderInsufficientNativeBalance.selector, 1, 0));
        sender.sync(0, amountToSync, new bytes(17), abi.encodePacked(uint128(1), false));
    }

    receive() external payable {}

    function _predictContractAddress(uint256 deltaNonce) private view returns (address) {
        uint256 nonce = vm.getNonce(address(this)) + deltaNonce;
        return vm.computeCreateAddress(address(this), nonce);
    }
}
