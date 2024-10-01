// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

interface ISyncAutomation is AutomationCompatibleInterface {
    error SyncAutomationInvalidAmounts(uint128 minAmount, uint128 maxAmount);
    error SyncAutomationInvalidParameters();
    error SyncAutomationNoUpkeepNeeded();
    error SyncAutomationOnlyForwarder();

    event AmountsSet(uint128 minAmount, uint128 maxAmount);
    event DelaySet(uint48 delay);
    event FeeDtoOSet(bytes fee);
    event FeeOtoDSet(bytes fee);
    event ForwarderSet(address forwarder);

    function DEST_CHAIN_SELECTOR() external view returns (uint64);
    function SENDER() external view returns (address);
    function WNATIVE() external view returns (address);
    function getAmountToSync() external view returns (uint256);
    function getAmounts() external view returns (uint128, uint128);
    function getDelay() external view returns (uint48);
    function getFeeDtoO() external view returns (bytes memory);
    function getFeeOtoD() external view returns (bytes memory);
    function getForwarder() external view returns (address);
    function getLastExecution() external view returns (uint48);
    function setAmounts(uint128 minAmount, uint128 maxAmount) external;
    function setDelay(uint48 delay) external;
    function setFeeDtoO(bytes memory fee) external;
    function setFeeOtoD(bytes memory fee) external;
    function setForwarder(address forwarder) external;
    function sweep(address token, address recipient, uint256 amount) external;
}
