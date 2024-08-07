// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFraxFerry {
    struct BatchData {
        uint256 startTransactionNo;
        Transaction[] transactions;
    }

    struct Transaction {
        address user;
        uint64 amount;
        uint32 timestamp;
    }

    event Cancelled(uint256 index, bool cancel);
    event Depart(uint256 batchNo, uint256 start, uint256 end, bytes32 hash);
    event Disembark(uint256 start, uint256 end, bytes32 hash);
    event DisputeBatch(uint256 batchNo, bytes32 hash);
    event Embark(address indexed sender, uint256 index, uint256 amount, uint256 amountAfterFee, uint256 timestamp);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event OwnerNominated(address indexed newOwner);
    event Pause(bool paused);
    event RemoveBatch(uint256 batchNo);
    event SetCaptain(address indexed previousCaptain, address indexed newCaptain);
    event SetCrewmember(address indexed crewmember, bool set);
    event SetFee(
        uint256 previousFeeRate,
        uint256 feeRate,
        uint256 previousFeeMin,
        uint256 feeMin,
        uint256 previousFeeMax,
        uint256 feeMax
    );
    event SetFirstOfficer(address indexed previousFirstOfficer, address indexed newFirstOfficer);
    event SetMinWaitPeriods(
        uint256 previousMinWaitAdd, uint256 previousMinWaitExecute, uint256 minWaitAdd, uint256 minWaitExecute
    );

    function FEE_MAX() external view returns (uint256);
    function FEE_MIN() external view returns (uint256);
    function FEE_RATE() external view returns (uint256);
    function MIN_WAIT_PERIOD_ADD() external view returns (uint256);
    function MIN_WAIT_PERIOD_EXECUTE() external view returns (uint256);
    function REDUCED_DECIMALS() external view returns (uint256);
    function acceptOwnership() external;
    function batches(uint256)
        external
        view
        returns (uint64 start, uint64 end, uint64 departureTime, uint64 status, bytes32 hash);
    function cancelled(uint256) external view returns (bool);
    function captain() external view returns (address);
    function chainid() external view returns (uint256);
    function crewmembers(address) external view returns (bool);
    function depart(uint256 start, uint256 end, bytes32 hash) external;
    function disembark(BatchData memory batchData) external;
    function disputeBatch(uint256 batchNo, bytes32 hash) external;
    function embark(uint256 amount) external;
    function embarkWithRecipient(uint256 amount, address recipient) external;
    function embarkWithSignature(
        uint256 _amount,
        address recipient,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function execute(address _to, uint256 _value, bytes memory _data) external returns (bool, bytes memory);
    function executeIndex() external view returns (uint256);
    function firstOfficer() external view returns (address);
    function getBatchAmount(uint256 start, uint256 end) external view returns (uint256 totalAmount);
    function getBatchData(uint256 start, uint256 end) external view returns (BatchData memory data);
    function getNextBatch(uint256 _start, uint256 max)
        external
        view
        returns (uint256 start, uint256 end, bytes32 hash);
    function getTransactionsHash(uint256 start, uint256 end) external view returns (bytes32);
    function jettison(uint256 index, bool cancel) external;
    function jettisonGroup(uint256[] memory indexes, bool cancel) external;
    function noBatches() external view returns (uint256);
    function noTransactions() external view returns (uint256);
    function nominateNewOwner(address newOwner) external;
    function nominatedOwner() external view returns (address);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function removeBatches(uint256 batchNo) external;
    function sendTokens(address receiver, uint256 amount) external;
    function setCaptain(address newCaptain) external;
    function setCrewmember(address crewmember, bool set) external;
    function setFee(uint256 _FEE_RATE, uint256 _FEE_MIN, uint256 _FEE_MAX) external;
    function setFirstOfficer(address newFirstOfficer) external;
    function setMinWaitPeriods(uint256 _MIN_WAIT_PERIOD_ADD, uint256 _MIN_WAIT_PERIOD_EXECUTE) external;
    function targetChain() external view returns (uint256);
    function targetToken() external view returns (address);
    function token() external view returns (address);
    function transactions(uint256) external view returns (address user, uint64 amount, uint32 timestamp);
    function unPause() external;
}
