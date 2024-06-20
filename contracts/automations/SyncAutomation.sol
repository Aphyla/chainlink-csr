// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IOraclePool} from "../interfaces/IOraclePool.sol";

interface ISender {
    function LINK_TOKEN() external view returns (address);
    function WNATIVE() external view returns (address);
    function getOraclePool() external view returns (address);
    function sync(uint64 destChainSelector, uint256 quoteAmount, bytes calldata feeOtoD, bytes calldata feeDtoO)
        external
        payable;
}

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

    modifier onlyForwarder() {
        if (msg.sender != _forwarder) revert SyncAutomationOnlyForwarder();
        _;
    }

    constructor(address sender, uint64 destChainSelector, address initialOwner) Ownable(initialOwner) {
        SENDER = sender;
        DEST_CHAIN_SELECTOR = destChainSelector;
        WNATIVE = ISender(sender).WNATIVE();

        _lastExecution = uint48(block.timestamp);
        _delay = type(uint48).max; // Deactivated by default

        IERC20(ISender(sender).LINK_TOKEN()).forceApprove(sender, type(uint256).max);
    }

    function getForwarder() public view virtual returns (address) {
        return _forwarder;
    }

    function getLastExecution() public view virtual returns (uint48) {
        return _lastExecution;
    }

    function getDelay() public view virtual returns (uint48) {
        return _delay;
    }

    function getAmounts() public view virtual returns (uint128, uint128) {
        return (_minAmount, _maxAmount);
    }

    function getFeeOtoD() public view virtual returns (bytes memory) {
        return _feeOtoD;
    }

    function getFeeDtoO() public view virtual returns (bytes memory) {
        return _feeDtoO;
    }

    function getAmountToSync() public view virtual returns (uint256) {
        return _getAmountToSync();
    }

    function checkUpkeep(bytes calldata checkData)
        public
        virtual
        override
        cannotExecute
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return _checkUpKeep(checkData);
    }

    function performUpkeep(bytes calldata /* performData */ ) public virtual override onlyForwarder {
        uint256 amount = _getAmountToSync();

        if (amount == 0) revert SyncAutomationNoUpkeepNeeded();

        _lastExecution = uint48(block.timestamp);

        bytes memory feeOtoD = _feeOtoD;
        bytes memory feeDtoO = _feeDtoO;

        (uint256 maxFeeOtoD, bool payInLinkOtoD,) = FeeCodec.decodeCCIP(feeOtoD);
        uint256 feeAmountDtoO = FeeCodec.decodeFee(feeDtoO);

        uint256 nativeAmount = feeAmountDtoO + (payInLinkOtoD ? 0 : maxFeeOtoD);
        ISender(SENDER).sync{value: nativeAmount}(DEST_CHAIN_SELECTOR, amount, feeOtoD, feeDtoO);
    }

    function setForwarder(address forwarder) public virtual onlyOwner {
        _setForwarder(forwarder);
    }

    function setDelay(uint48 delay) public virtual onlyOwner {
        _setDelay(delay);
    }

    function setAmounts(uint128 minAmount, uint128 maxAmount) public virtual onlyOwner {
        _setAmounts(minAmount, maxAmount);
    }

    function setFeeOtoD(bytes calldata fee) public virtual onlyOwner {
        _setFeeOtoD(fee);
    }

    function setFeeDtoO(bytes calldata fee) public virtual onlyOwner {
        _setFeeDtoO(fee);
    }

    function _checkUpKeep(bytes calldata /* checkData */ )
        internal
        view
        virtual
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 amount = _getAmountToSync();
        return amount == 0 ? (false, new bytes(0)) : (true, abi.encode(amount));
    }

    function _getAmountToSync() internal view virtual returns (uint256 amount) {
        if (block.timestamp >= _lastExecution + _delay) {
            address oraclePool = ISender(SENDER).getOraclePool();
            uint256 wnativeAmount = IERC20(WNATIVE).balanceOf(oraclePool);

            if (wnativeAmount >= _minAmount) {
                uint256 maxAmount = _maxAmount;
                amount = wnativeAmount > maxAmount ? maxAmount : wnativeAmount;
            }
        }
    }

    function _setForwarder(address forwarder) internal virtual {
        _forwarder = forwarder;

        emit ForwarderSet(forwarder);
    }

    function _setDelay(uint48 delay) internal virtual {
        _delay = delay;

        emit DelaySet(delay);
    }

    function _setAmounts(uint128 minAmount, uint128 maxAmount) internal virtual {
        if (minAmount == 0 || minAmount > maxAmount) revert SyncAutomationInvalidAmounts(minAmount, maxAmount);

        _minAmount = minAmount;
        _maxAmount = maxAmount;

        emit AmountsSet(minAmount, maxAmount);
    }

    function _setFeeOtoD(bytes calldata fee) internal virtual {
        _feeOtoD = fee;

        emit FeeOtoDSet(fee);
    }

    function _setFeeDtoO(bytes calldata fee) internal virtual {
        _feeDtoO = fee;

        emit FeeDtoOSet(fee);
    }
}
