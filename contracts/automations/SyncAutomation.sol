// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IOraclePool} from "../interfaces/IOraclePool.sol";
import {ICustomSender} from "../interfaces/ICustomSender.sol";

/**
 * @title SyncAutomation Contract
 * @dev A contract that automates the synchronization of native tokens to another chain using the Chainlink automation framework.
 * The synchronization is done every `delay` seconds if the amount of native tokens in the oracle pool is greater than `minAmount`.
 * The amount of native tokens to sync is the minimum between the amount in the oracle pool and `maxAmount`.
 */
contract SyncAutomation is AutomationCompatible, Ownable2Step {
    using SafeERC20 for IERC20;

    error SyncAutomationOnlyForwarder();
    error SyncAutomationNoUpkeepNeeded();
    error SyncAutomationInvalidAmounts(uint128 minAmount, uint128 maxAmount);

    event ForwarderSet(address forwarder);
    event DelaySet(uint48 delay);
    event AmountsSet(uint128 minAmount, uint128 maxAmount);
    event FeeOtoDSet(bytes fee);
    event FeeDtoOSet(bytes fee);

    address public immutable SENDER;
    uint64 public immutable DEST_CHAIN_SELECTOR;
    address public immutable WNATIVE;

    address private _forwarder;
    uint48 private _lastExecution;
    uint48 private _delay;

    uint128 private _minAmount;
    uint128 private _maxAmount;

    bytes private _feeOtoD;
    bytes private _feeDtoO;

    /**
     * @dev Modifier to check that the caller is the forwarder.
     */
    modifier onlyForwarder() {
        if (msg.sender != _forwarder) revert SyncAutomationOnlyForwarder();
        _;
    }

    /**
     * @dev Sets the immutable values for {SENDER}, {DEST_CHAIN_SELECTOR} and set the initial owner.
     * The {WNATIVE} address is retrieved from the {SENDER} contract.
     * Sets the last execution timestamp to the current block timestamp and the delay to the maximum value to
     * prevent any unwanted execution.
     * Approves the maximum amount of LINK tokens to the {SENDER} contract to allow the payment of link fees for the
     * CCIP messages.
     */
    constructor(address sender, uint64 destChainSelector, address initialOwner) Ownable(initialOwner) {
        SENDER = sender;
        DEST_CHAIN_SELECTOR = destChainSelector;
        WNATIVE = ICustomSender(sender).WNATIVE();

        _lastExecution = uint48(block.timestamp);
        _delay = type(uint48).max; // Deactivated by default

        IERC20(ICustomSender(sender).LINK_TOKEN()).forceApprove(sender, type(uint256).max);
    }

    /**
     * @dev Returns the address of the forwarder.
     */
    function getForwarder() public view virtual returns (address) {
        return _forwarder;
    }

    /**
     * @dev Returns the last execution timestamp.
     */
    function getLastExecution() public view virtual returns (uint48) {
        return _lastExecution;
    }

    /**
     * @dev Returns the minimum delay between executions.
     */
    function getDelay() public view virtual returns (uint48) {
        return _delay;
    }

    /**
     * @dev Returns the minimum and maximum amounts of native tokens to sync.
     */
    function getAmounts() public view virtual returns (uint128, uint128) {
        return (_minAmount, _maxAmount);
    }

    /**
     * @dev Returns the fee for the cross-chain message from the origin to the destination chain.
     */
    function getFeeOtoD() public view virtual returns (bytes memory) {
        return _feeOtoD;
    }

    /**
     * @dev Returns the fee for the cross-chain message from the destination to the origin chain.
     */
    function getFeeDtoO() public view virtual returns (bytes memory) {
        return _feeDtoO;
    }

    /**
     * @dev Returns the amount of native tokens that can be synced.
     */
    function getAmountToSync() public view virtual returns (uint256) {
        return _getAmountToSync();
    }

    /**
     * @dev Function called by the Chainlink Keeper network to check if the upkeep is needed.
     * If the amount of native tokens in the oracle pool is greater than `minAmount` and the delay has passed,
     * the upkeep is needed.
     */
    function checkUpkeep(bytes calldata checkData)
        public
        virtual
        override
        cannotExecute
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return _checkUpKeep(checkData);
    }

    /**
     * @dev Function called by the Chainlink Keeper network to perform the upkeep.
     * If the amount of native tokens in the oracle pool is greater than `minAmount`, the native tokens are synced
     * to the destination chain.
     *
     * Requirements:
     *
     * - The caller must be the forwarder.
     * - The amount of native tokens in the oracle pool must be greater than `minAmount` (i.e. the upkeep is needed).
     */
    function performUpkeep(bytes calldata /* performData */ ) public virtual override onlyForwarder {
        uint256 amount = _getAmountToSync();

        if (amount == 0) revert SyncAutomationNoUpkeepNeeded();

        _lastExecution = uint48(block.timestamp);

        bytes memory feeOtoD = _feeOtoD;
        bytes memory feeDtoO = _feeDtoO;

        (uint256 maxFeeOtoD, bool payInLinkOtoD,) = FeeCodec.decodeCCIP(feeOtoD);
        uint256 feeAmountDtoO = FeeCodec.decodeFee(feeDtoO);

        uint256 nativeAmount = feeAmountDtoO + (payInLinkOtoD ? 0 : maxFeeOtoD);
        ICustomSender(SENDER).sync{value: nativeAmount}(DEST_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);
    }

    /**
     * @dev Sets the forwarder address.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner.
     *
     * Emits a {ForwarderSet} event.
     */
    function setForwarder(address forwarder) public virtual onlyOwner {
        _setForwarder(forwarder);
    }

    function setDelay(uint48 delay) public virtual onlyOwner {
        _setDelay(delay);
    }

    /**
     * @dev Sets the minimum and maximum amounts of native tokens to sync.
     *
     * Requirements:
     *
     * - `minAmount` must be greater than 0.
     * - `minAmount` must be less than or equal to `maxAmount`.
     *
     * Emits a {AmountsSet} event.
     */
    function setAmounts(uint128 minAmount, uint128 maxAmount) public virtual onlyOwner {
        _setAmounts(minAmount, maxAmount);
    }

    /**
     * @dev Sets the fee for the cross-chain message from the origin to the destination chain.
     * The fee will be checked on the source chain, and will revert if the fee is insufficient.
     *
     * Emits a {FeeOtoDSet} event.
     */
    function setFeeOtoD(bytes calldata fee) public virtual onlyOwner {
        _setFeeOtoD(fee);
    }

    /**
     * @dev Sets the fee for the cross-chain message from the destination to the origin chain.
     * The fee will only be checked on the destination chain, which won't revert on the source chain if the fee is insufficient.
     * It is therefore very important to set the fee correctly to avoid any issues, preferably higher than the expected fee.
     *
     * Emits a {FeeDtoOSet} event.
     */
    function setFeeDtoO(bytes calldata fee) public virtual onlyOwner {
        _setFeeDtoO(fee);
    }

    /**
     * @dev Returns whether the upkeep is needed and the amount of native tokens to sync.
     * If the amount of native tokens in the oracle pool is greater than `minAmount` and the delay has passed,
     * the upkeep is needed.
     */
    function _checkUpKeep(bytes calldata /* checkData */ )
        internal
        view
        virtual
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 amount = _getAmountToSync();
        return amount == 0 ? (false, new bytes(0)) : (true, abi.encode(amount));
    }

    /**
     * @dev Returns the amount of native tokens that can be synced.
     * The amount is the minimum between the amount in the oracle pool and `maxAmount` if the delay has passed.
     */
    function _getAmountToSync() internal view virtual returns (uint256 amount) {
        if (block.timestamp >= _lastExecution + _delay) {
            address oraclePool = ICustomSender(SENDER).getOraclePool();
            uint256 wnativeAmount = IERC20(WNATIVE).balanceOf(oraclePool);

            if (wnativeAmount >= _minAmount) {
                uint256 maxAmount = _maxAmount;
                amount = wnativeAmount > maxAmount ? maxAmount : wnativeAmount;
            }
        }
    }

    /**
     * @dev Sets the forwarder address.
     *
     * Emits a {ForwarderSet} event.
     */
    function _setForwarder(address forwarder) internal virtual {
        _forwarder = forwarder;

        emit ForwarderSet(forwarder);
    }

    /**
     * @dev Sets the delay between executions.
     *
     * Emits a {DelaySet} event.
     */
    function _setDelay(uint48 delay) internal virtual {
        _delay = delay;

        emit DelaySet(delay);
    }

    /**
     * @dev Sets the minimum and maximum amounts of native tokens to sync.
     *
     * Emits a {AmountsSet} event.
     */
    function _setAmounts(uint128 minAmount, uint128 maxAmount) internal virtual {
        if (minAmount == 0 || minAmount > maxAmount) revert SyncAutomationInvalidAmounts(minAmount, maxAmount);

        _minAmount = minAmount;
        _maxAmount = maxAmount;

        emit AmountsSet(minAmount, maxAmount);
    }

    /**
     * @dev Sets the fee for the cross-chain message from the origin to the destination chain.
     *
     * Emits a {FeeOtoDSet} event.
     */
    function _setFeeOtoD(bytes calldata fee) internal virtual {
        _feeOtoD = fee;

        emit FeeOtoDSet(fee);
    }

    /**
     * @dev Sets the fee for the cross-chain message from the destination to the origin chain.
     *
     * Emits a {FeeDtoOSet} event.
     */
    function _setFeeDtoO(bytes calldata fee) internal virtual {
        _feeDtoO = fee;

        emit FeeDtoOSet(fee);
    }
}
