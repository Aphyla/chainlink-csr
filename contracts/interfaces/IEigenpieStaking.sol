// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEigenpieStaking {
    error AssetNotSupported();
    error CallerNotEigenpieConfigAdmin();
    error CallerNotEigenpieConfigManager();
    error InvalidAmountToDeposit();
    error InvalidCaller();
    error InvalidIndex();
    error InvalidMaximumNodeDelegatorLimit();
    error LengthMismatch();
    error MaximumDepositLimitReached();
    error MaximumNodeDelegatorLimitReached();
    error MinimumAmountToReceiveNotMet();
    error NativeTokenTransferFailed();
    error NotEnoughAssetToTransfer();
    error OnlyWhenPredeposit();
    error TokenTransferFailed();
    error ZeroAddressNotAllowed();

    event AssetDeposit(
        address indexed depositor,
        address indexed asset,
        uint256 depositAmount,
        address indexed referral,
        uint256 mintedAmount,
        bool isPreDepsoit
    );
    event Initialized(uint8 version);
    event MaxNodeDelegatorLimitUpdated(uint256 maxNodeDelegatorLimit);
    event MinAmountToDepositUpdated(uint256 minAmountToDeposit);
    event NodeDelegatorAddedinQueue(address[] nodeDelegatorContracts);
    event Paused(address account);
    event PreDepositHelperChanged(address oldPreDepositHelper, address newPreDepositHelper);
    event PreDepositStatusChanged(bool newIsPreDeposit);
    event Unpaused(address account);
    event UpdatedEigenpieConfig(address indexed eigenpieConfig);

    function addNodeDelegatorContractToQueue(address[] memory nodeDelegatorContracts) external;
    function depositAsset(address asset, uint256 depositAmount, uint256 minRec, address referral) external payable;
    function eigenpieConfig() external view returns (address);
    function getAssetCurrentLimit(address asset) external view returns (uint256);
    function getAssetDistributionData(address asset)
        external
        view
        returns (uint256 assetLyingInDepositPool, uint256 assetLyingInNDCs, uint256 assetStakedInEigenLayer);
    function getMLRTAmountToMint(address asset, uint256 amount)
        external
        view
        returns (uint256 mLRTAmountToMint, address mLRTReceipt);
    function getNodeDelegatorQueue() external view returns (address[] memory);
    function getTotalAssetDeposits(address asset) external view returns (uint256 totalAssetDeposit);
    function initialize(address eigenpieConfigAddr) external;
    function isNodeDelegator(address) external view returns (uint256);
    function isPreDeposit() external view returns (bool);
    function maxNodeDelegatorLimit() external view returns (uint256);
    function minAmountToDeposit() external view returns (uint256);
    function nodeDelegatorQueue(uint256) external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function setIsPreDeposit(bool _isPreDeposit) external;
    function setMinAmountToDeposit(uint256 minAmountToDeposit_) external;
    function transferAssetToNodeDelegator(uint256 ndcIndex, address asset, uint256 amount) external;
    function unpause() external;
    function updateEigenpieConfig(address eigenpieConfigAddr) external;
    function updateMaxNodeDelegatorLimit(uint256 maxNodeDelegatorLimit_) external;
}
