// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import "../../contracts/automations/SyncAutomation.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockWNative.sol";

contract SyncAutomationTest is Test {
    SyncAutomation public syncAutomation;
    MockSender public sender;
    MockERC20 public link;
    MockWNative public wnative;

    address public immutable ORACLE_POOL = makeAddr("OraclePool");
    address public immutable FORWARDER = makeAddr("Forwarder");
    uint64 public immutable DEST_CHAIN_SELECTOR = 123456789;

    function setUp() public {
        wnative = new MockWNative();
        link = new MockERC20("Link", "LINK", 18);
        sender = new MockSender(address(wnative), address(link), ORACLE_POOL);

        syncAutomation = new SyncAutomation(address(sender), DEST_CHAIN_SELECTOR, address(this));
    }

    function test_Constructor() public {
        syncAutomation = new SyncAutomation(address(sender), DEST_CHAIN_SELECTOR, address(this)); // to fix coverage

        assertEq(syncAutomation.SENDER(), address(sender), "test_Constructor::1");
        assertEq(syncAutomation.DEST_CHAIN_SELECTOR(), DEST_CHAIN_SELECTOR, "test_Constructor::2");
        assertEq(syncAutomation.WNATIVE(), address(wnative), "test_Constructor::3");
        assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Constructor::4");
        assertEq(syncAutomation.getLastExecution(), uint48(block.timestamp), "test_Constructor::5");
        assertEq(link.allowance(address(syncAutomation), address(sender)), type(uint256).max, "test_Constructor::6");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(ISyncAutomation.SyncAutomationInvalidParameters.selector);
        syncAutomation = new SyncAutomation(address(0), DEST_CHAIN_SELECTOR, address(this));

        vm.expectRevert(ISyncAutomation.SyncAutomationInvalidParameters.selector);
        syncAutomation = new SyncAutomation(address(sender), 0, address(this));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        syncAutomation = new SyncAutomation(address(sender), DEST_CHAIN_SELECTOR, address(0));
    }

    function test_Fuzz_SetForwarder(address forwarder) public {
        assertEq(syncAutomation.getForwarder(), address(0), "test_Fuzz_SetForwarder::1");

        syncAutomation.setForwarder(forwarder);

        assertEq(syncAutomation.getForwarder(), forwarder, "test_Fuzz_SetForwarder::2");

        syncAutomation.setForwarder(address(0));

        assertEq(syncAutomation.getForwarder(), address(0), "test_Fuzz_SetForwarder::3");

        syncAutomation.setForwarder(forwarder);

        assertEq(syncAutomation.getForwarder(), forwarder, "test_Fuzz_SetForwarder::4");
    }

    function test_Fuzz_SetDelay(uint48 delay) public {
        assertEq(syncAutomation.getDelay(), type(uint48).max, "test_Fuzz_SetDelay::1");

        syncAutomation.setDelay(delay);

        assertEq(syncAutomation.getDelay(), delay, "test_Fuzz_SetDelay::2");

        syncAutomation.setDelay(0);

        assertEq(syncAutomation.getDelay(), 0, "test_Fuzz_SetDelay::3");

        syncAutomation.setDelay(delay);

        assertEq(syncAutomation.getDelay(), delay, "test_Fuzz_SetDelay::4");
    }

    function test_Fuzz_SetAmounts(uint128 minAmount, uint128 maxAmount) public {
        minAmount = uint128(bound(minAmount, 1, type(uint128).max));
        maxAmount = uint128(bound(maxAmount, minAmount, type(uint128).max));

        (uint128 minAmount_, uint128 maxAmount_) = syncAutomation.getAmounts();

        assertEq(minAmount_, 0, "test_Fuzz_SetAmounts::1");
        assertEq(maxAmount_, 0, "test_Fuzz_SetAmounts::2");

        syncAutomation.setAmounts(minAmount, maxAmount);

        (minAmount_, maxAmount_) = syncAutomation.getAmounts();

        assertEq(minAmount_, minAmount, "test_Fuzz_SetAmounts::3");
        assertEq(maxAmount_, maxAmount, "test_Fuzz_SetAmounts::4");

        syncAutomation.setAmounts(1, minAmount);

        (minAmount_, maxAmount_) = syncAutomation.getAmounts();

        assertEq(minAmount_, 1, "test_Fuzz_SetAmounts::5");
        assertEq(maxAmount_, minAmount, "test_Fuzz_SetAmounts::6");

        syncAutomation.setAmounts(minAmount, type(uint128).max);

        (minAmount_, maxAmount_) = syncAutomation.getAmounts();

        assertEq(minAmount_, minAmount, "test_Fuzz_SetAmounts::7");
        assertEq(maxAmount_, type(uint128).max, "test_Fuzz_SetAmounts::8");

        syncAutomation.setAmounts(minAmount, maxAmount);

        (minAmount_, maxAmount_) = syncAutomation.getAmounts();

        assertEq(minAmount_, minAmount, "test_Fuzz_SetAmounts::9");
        assertEq(maxAmount_, maxAmount, "test_Fuzz_SetAmounts::10");
    }

    function test_Fuzz_Revert_SetAmounts(uint128 minAmount, uint128 maxAmount) public {
        minAmount = uint128(bound(minAmount, 1, type(uint128).max));
        maxAmount = uint128(bound(maxAmount, 0, minAmount - 1));

        vm.expectRevert(abi.encodeWithSelector(ISyncAutomation.SyncAutomationInvalidAmounts.selector, 0, 1));
        syncAutomation.setAmounts(0, 1);

        vm.expectRevert(
            abi.encodeWithSelector(ISyncAutomation.SyncAutomationInvalidAmounts.selector, minAmount, maxAmount)
        );
        syncAutomation.setAmounts(minAmount, maxAmount);
    }

    function test_Fuzz_SetFeeOtoD(bytes memory fee) public {
        assertEq(syncAutomation.getFeeOtoD(), new bytes(0), "test_Fuzz_SetFeeOtoD::1");

        syncAutomation.setFeeOtoD(fee);

        assertEq(syncAutomation.getFeeOtoD(), fee, "test_Fuzz_SetFeeOtoD::2");

        syncAutomation.setFeeOtoD(new bytes(0));

        assertEq(syncAutomation.getFeeOtoD(), new bytes(0), "test_Fuzz_SetFeeOtoD::3");

        syncAutomation.setFeeOtoD(fee);

        assertEq(syncAutomation.getFeeOtoD(), fee, "test_Fuzz_SetFeeOtoD::4");
    }

    function test_Fuzz_SetFeeDtoO(bytes memory fee) public {
        assertEq(syncAutomation.getFeeDtoO(), new bytes(0), "test_Fuzz_SetFeeDtoO::1");

        syncAutomation.setFeeDtoO(fee);

        assertEq(syncAutomation.getFeeDtoO(), fee, "test_Fuzz_SetFeeDtoO::2");

        syncAutomation.setFeeDtoO(new bytes(0));

        assertEq(syncAutomation.getFeeDtoO(), new bytes(0), "test_Fuzz_SetFeeDtoO::3");

        syncAutomation.setFeeDtoO(fee);

        assertEq(syncAutomation.getFeeDtoO(), fee, "test_Fuzz_SetFeeDtoO::4");
    }

    function test_Fuzz_GetMaxFees(
        uint128 maxFee0toD,
        bool payInLink0toD,
        uint128 maxFeeDto0,
        bool payInLinkDto0,
        bytes memory otherData
    ) public {
        bytes memory fee0toD = abi.encodePacked(maxFee0toD, payInLink0toD, otherData);
        bytes memory feeDto0 = abi.encodePacked(maxFeeDto0, payInLinkDto0, otherData);

        syncAutomation.setFeeOtoD(fee0toD);
        syncAutomation.setFeeDtoO(feeDto0);

        (uint256 maxNativeFee, uint256 maxLinkFee) = syncAutomation.getMaxFees();

        uint256 expectedMaxNativeFee = uint256(payInLink0toD ? 0 : maxFee0toD) + (payInLinkDto0 ? 0 : maxFeeDto0);
        uint256 expectedMaxLinkFee = uint256(payInLink0toD ? maxFee0toD : 0) + (payInLinkDto0 ? maxFeeDto0 : 0);

        assertEq(maxNativeFee, expectedMaxNativeFee, "test_Fuzz_GetMaxFee::1");
        assertEq(maxLinkFee, expectedMaxLinkFee, "test_Fuzz_GetMaxFee::2");
    }

    function test_Fuzz_Revert_OnlyOwner(address msgSender) public {
        vm.assume(msgSender != address(this));

        vm.startPrank(msgSender);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msgSender));
        syncAutomation.setForwarder(address(0));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msgSender));
        syncAutomation.setDelay(0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msgSender));
        syncAutomation.setAmounts(0, 0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msgSender));
        syncAutomation.setFeeOtoD(new bytes(0));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msgSender));
        syncAutomation.setFeeDtoO(new bytes(0));

        vm.stopPrank();
    }

    function test_Fuzz_CheckUpkeep(uint128 minAmount, uint128 maxAmount, uint48 delay) public {
        minAmount = uint128(bound(minAmount, 1, 100e18));
        maxAmount = uint128(bound(maxAmount, minAmount, 100e18));
        delay = uint48(bound(delay, 1, type(uint32).max));

        uint256 timestamp = block.timestamp;

        syncAutomation.setAmounts(minAmount, maxAmount);
        syncAutomation.setDelay(delay);

        {
            uint256 amount = syncAutomation.getAmountToSync();
            vm.prank(address(0), address(0));
            (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

            assertEq(amount, 0, "test_Fuzz_CheckUpkeep::1");
            assertEq(upkeepNeeded, false, "test_Fuzz_CheckUpkeep::2");
            assertEq(performData, new bytes(0), "test_Fuzz_CheckUpkeep::3");
        }

        wnative.deposit{value: 2 * maxAmount}();
        wnative.transfer(address(ORACLE_POOL), minAmount - 1);

        {
            uint256 amount = syncAutomation.getAmountToSync();
            vm.prank(
                address(0x1111111111111111111111111111111111111111), address(0x1111111111111111111111111111111111111111)
            );
            (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

            assertEq(amount, 0, "test_Fuzz_CheckUpkeep::4");
            assertEq(upkeepNeeded, false, "test_Fuzz_CheckUpkeep::5");
            assertEq(performData, new bytes(0), "test_Fuzz_CheckUpkeep::6");
        }

        wnative.transfer(address(ORACLE_POOL), 1);

        {
            uint256 amount = syncAutomation.getAmountToSync();
            vm.prank(address(0), address(0));
            (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

            assertEq(amount, 0, "test_Fuzz_CheckUpkeep::7");
            assertEq(upkeepNeeded, false, "test_Fuzz_CheckUpkeep::8");
            assertEq(performData, new bytes(0), "test_Fuzz_CheckUpkeep::9");
        }

        vm.warp(timestamp + delay);

        {
            uint256 amount = syncAutomation.getAmountToSync();
            vm.prank(
                address(0x1111111111111111111111111111111111111111), address(0x1111111111111111111111111111111111111111)
            );
            (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

            assertEq(amount, minAmount, "test_Fuzz_CheckUpkeep::10");
            assertEq(upkeepNeeded, true, "test_Fuzz_CheckUpkeep::11");
            assertEq(performData, abi.encode(amount), "test_Fuzz_CheckUpkeep::12");
        }

        wnative.transfer(address(ORACLE_POOL), maxAmount - minAmount);

        {
            uint256 amount = syncAutomation.getAmountToSync();
            vm.prank(address(0), address(0));
            (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

            assertEq(amount, maxAmount, "test_Fuzz_CheckUpkeep::13");
            assertEq(upkeepNeeded, true, "test_Fuzz_CheckUpkeep::14");
            assertEq(performData, abi.encode(amount), "test_Fuzz_CheckUpkeep::15");
        }

        wnative.transfer(address(ORACLE_POOL), 1);

        {
            uint256 amount = syncAutomation.getAmountToSync();
            vm.prank(
                address(0x1111111111111111111111111111111111111111), address(0x1111111111111111111111111111111111111111)
            );
            (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

            assertEq(amount, maxAmount, "test_Fuzz_CheckUpkeep::16");
            assertEq(upkeepNeeded, true, "test_Fuzz_CheckUpkeep::17");
            assertEq(performData, abi.encode(amount), "test_Fuzz_CheckUpkeep::18");
        }

        vm.warp(timestamp + delay - 1);

        {
            uint256 amount = syncAutomation.getAmountToSync();
            vm.prank(address(0), address(0));
            (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

            assertEq(amount, 0, "test_Fuzz_CheckUpkeep::19");
            assertEq(upkeepNeeded, false, "test_Fuzz_CheckUpkeep::20");
            assertEq(performData, new bytes(0), "test_Fuzz_CheckUpkeep::21");
        }
    }

    function test_Fuzz_Revert_CheckUpkeep(address msgSender) public {
        vm.assume(msgSender != address(0) && msgSender != address(0x1111111111111111111111111111111111111111));

        vm.prank(msgSender);
        vm.expectRevert(AutomationBase.OnlySimulatedBackend.selector);
        syncAutomation.checkUpkeep(new bytes(0));
    }

    function test_Fuzz_PerformUpKeep(
        uint128 amount,
        uint48 delay,
        uint128 maxFeeOtoD,
        bool payInLinkOtoD,
        uint32 maxGasOtoD,
        uint128 maxFeeDtoO,
        bool payInLinkDtoO
    ) public {
        amount = uint128(bound(amount, 1, 100e18));
        delay = uint48(bound(delay, 1, type(uint32).max));
        maxFeeOtoD = uint128(bound(maxFeeOtoD, 0, 10e18));
        maxFeeDtoO = uint128(bound(maxFeeDtoO, 0, 10e18));

        syncAutomation.setAmounts(amount, amount);
        syncAutomation.setDelay(delay);
        syncAutomation.setFeeOtoD(FeeCodec.encodeCCIP(maxFeeOtoD, payInLinkOtoD, maxGasOtoD));
        syncAutomation.setFeeDtoO(abi.encodePacked(maxFeeDtoO, payInLinkDtoO, msg.data));
        syncAutomation.setForwarder(FORWARDER);

        uint256 nativeFee = (payInLinkDtoO ? 0 : maxFeeDtoO) + (payInLinkOtoD ? 0 : maxFeeOtoD);

        vm.warp(block.timestamp + delay);
        vm.deal(address(syncAutomation), nativeFee);

        wnative.deposit{value: amount}();
        wnative.transfer(address(ORACLE_POOL), amount);

        vm.prank(address(0), address(0));
        (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

        assertEq(upkeepNeeded, true, "test_Fuzz_PerformUpKeep::1");
        assertEq(performData, abi.encode(amount), "test_Fuzz_PerformUpKeep::2");

        vm.prank(FORWARDER);
        syncAutomation.performUpkeep(performData);

        assertEq(sender.value(), nativeFee, "test_Fuzz_PerformUpKeep::3");
        assertEq(
            sender.data(),
            abi.encodeWithSelector(
                ICustomSender.sync.selector,
                DEST_CHAIN_SELECTOR,
                amount,
                syncAutomation.getFeeOtoD(),
                syncAutomation.getFeeDtoO()
            ),
            "test_Fuzz_PerformUpKeep::4"
        );
    }

    function test_Fuzz_Revert_PerformUpKeep(
        address msgSender,
        uint128 amount,
        uint48 delay,
        uint128 maxFeeOtoD,
        bool payInLinkOtoD,
        uint32 maxGasOtoD,
        uint128 maxFeeDtoO,
        bool payInLinkDtoO
    ) public {
        vm.assume(msgSender != FORWARDER);

        amount = uint128(bound(amount, 1, 100e18));
        delay = uint48(bound(delay, 1, type(uint32).max));
        maxFeeOtoD = uint128(bound(maxFeeOtoD, 0, 10e18));
        maxFeeDtoO = uint128(bound(maxFeeDtoO, 0, 10e18));

        syncAutomation.setAmounts(amount, amount);
        syncAutomation.setDelay(delay);
        syncAutomation.setFeeOtoD(FeeCodec.encodeCCIP(maxFeeOtoD, payInLinkOtoD, maxGasOtoD));
        syncAutomation.setFeeDtoO(abi.encodePacked(maxFeeDtoO, payInLinkDtoO, msg.data));
        syncAutomation.setForwarder(FORWARDER);

        uint256 nativeFee = (payInLinkDtoO ? 0 : maxFeeDtoO) + (payInLinkOtoD ? 0 : maxFeeOtoD);

        vm.warp(block.timestamp + delay);
        vm.deal(address(syncAutomation), nativeFee);

        wnative.deposit{value: amount}();
        wnative.transfer(address(ORACLE_POOL), amount);

        vm.prank(address(0), address(0));
        (bool upkeepNeeded, bytes memory performData) = syncAutomation.checkUpkeep(new bytes(0));

        assertEq(upkeepNeeded, true, "test_Fuzz_Revert_PerformUpKeep::1");
        assertEq(performData, abi.encode(amount), "test_Fuzz_Revert_PerformUpKeep::2");

        vm.prank(msgSender);
        vm.expectRevert(ISyncAutomation.SyncAutomationOnlyForwarder.selector);
        syncAutomation.performUpkeep(performData);

        syncAutomation.setDelay(delay + 1);

        vm.prank(FORWARDER);
        vm.expectRevert(ISyncAutomation.SyncAutomationNoUpkeepNeeded.selector);
        syncAutomation.performUpkeep(performData);
    }
}

contract MockSender {
    address public immutable WNATIVE;
    address public immutable LINK_TOKEN;
    address public immutable getOraclePool;

    uint256 public value;
    bytes public data;

    constructor(address wnative, address linkToken, address oraclePool) {
        WNATIVE = wnative;
        LINK_TOKEN = linkToken;
        getOraclePool = oraclePool;
    }

    function sync(uint64, uint256, bytes calldata, bytes calldata) external payable returns (uint256) {
        value = msg.value;
        data = msg.data;

        return 0;
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
