// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

library IPauseManager {
    type PauseType is uint8;

    struct PauseTypeRole {
        PauseType pauseType;
        bytes32 role;
    }
}

library IPermissionsManager {
    struct RoleAddress {
        address addressWithRole;
        bytes32 role;
    }
}

library ITokenBridge {
    struct InitializationData {
        address defaultAdmin;
        address messageService;
        address tokenBeacon;
        uint256 sourceChainId;
        uint256 targetChainId;
        address[] reservedTokens;
        IPermissionsManager.RoleAddress[] roleAddresses;
        IPauseManager.PauseTypeRole[] pauseTypeRoles;
        IPauseManager.PauseTypeRole[] unpauseTypeRoles;
    }
}

interface ILineaTokenBridge {
    error AlreadyBridgedToken(address token);
    error AlreadyBrigedToNativeTokenSet(address token);
    error ArrayLengthsDoNotMatch();
    error CallerIsNotMessageService();
    error DecimalsAreUnknown(address token);
    error InvalidPermitData(bytes4 permitData, bytes4 permitSelector);
    error IsNotPaused(IPauseManager.PauseType pauseType);
    error IsPaused(IPauseManager.PauseType pauseType);
    error NativeToBridgedTokenAlreadySet(address token);
    error NotReserved(address token);
    error PermitNotAllowingBridge(address spender);
    error PermitNotFromSender(address owner);
    error RemoteTokenBridgeAlreadySet(address remoteTokenBridge);
    error ReservedToken(address token);
    error SenderNotAuthorized();
    error StatusAddressNotAllowed(address token);
    error TokenListEmpty();
    error TokenNotDeployed(address token);
    error ZeroAddressNotAllowed();
    error ZeroAmountNotAllowed(uint256 amount);
    error ZeroHashNotAllowed();

    event BridgingFinalized(
        address indexed nativeToken, address indexed bridgedToken, uint256 indexed amount, address recipient
    );
    event BridgingFinalizedV2(
        address indexed nativeToken, address indexed bridgedToken, uint256 amount, address indexed recipient
    );
    event BridgingInitiated(address indexed sender, address recipient, address indexed token, uint256 indexed amount);
    event BridgingInitiatedV2(address indexed sender, address indexed recipient, address indexed token, uint256 amount);
    event CustomContractSet(address indexed nativeToken, address indexed customContract, address indexed setBy);
    event DeploymentConfirmed(address[] tokens, address indexed confirmedBy);
    event Initialized(uint8 version);
    event MessageServiceUpdated(
        address indexed newMessageService, address indexed oldMessageService, address indexed setBy
    );
    event NewToken(address indexed token);
    event NewTokenDeployed(address indexed bridgedToken, address indexed nativeToken);
    event PauseTypeRoleSet(IPauseManager.PauseType indexed pauseType, bytes32 indexed role);
    event Paused(address messageSender, IPauseManager.PauseType indexed pauseType);
    event RemoteSenderSet(address indexed remoteSender, address indexed setter);
    event RemoteTokenBridgeSet(address indexed remoteTokenBridge, address indexed setBy);
    event ReservationRemoved(address indexed token);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event TokenDeployed(address indexed token);
    event TokenReserved(address indexed token);
    event UnPauseTypeRoleSet(IPauseManager.PauseType indexed unPauseType, bytes32 indexed role);
    event UnPaused(address messageSender, IPauseManager.PauseType indexed pauseType);

    function CONTRACT_VERSION() external view returns (string memory);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function PAUSE_ALL_ROLE() external view returns (bytes32);
    function PAUSE_COMPLETE_TOKEN_BRIDGING_ROLE() external view returns (bytes32);
    function PAUSE_INITIATE_TOKEN_BRIDGING_ROLE() external view returns (bytes32);
    function REMOVE_RESERVED_TOKEN_ROLE() external view returns (bytes32);
    function SET_CUSTOM_CONTRACT_ROLE() external view returns (bytes32);
    function SET_MESSAGE_SERVICE_ROLE() external view returns (bytes32);
    function SET_REMOTE_TOKENBRIDGE_ROLE() external view returns (bytes32);
    function SET_RESERVED_TOKEN_ROLE() external view returns (bytes32);
    function UNPAUSE_ALL_ROLE() external view returns (bytes32);
    function UNPAUSE_COMPLETE_TOKEN_BRIDGING_ROLE() external view returns (bytes32);
    function UNPAUSE_INITIATE_TOKEN_BRIDGING_ROLE() external view returns (bytes32);
    function bridgeToken(address _token, uint256 _amount, address _recipient) external payable;
    function bridgeTokenWithPermit(address _token, uint256 _amount, address _recipient, bytes memory _permitData)
        external
        payable;
    function bridgedToNativeToken(address bridged) external view returns (address native);
    function completeBridging(
        address _nativeToken,
        uint256 _amount,
        address _recipient,
        uint256 _chainId,
        bytes memory _tokenMetadata
    ) external;
    function confirmDeployment(address[] memory _tokens) external payable;
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function initialize(ITokenBridge.InitializationData memory _initializationData) external;
    function isPaused(IPauseManager.PauseType _pauseType) external view returns (bool pauseTypeIsPaused);
    function messageService() external view returns (address);
    function nativeToBridgedToken(uint256 chainId, address native) external view returns (address bridged);
    function pauseByType(IPauseManager.PauseType _pauseType) external;
    function pauseTypeStatuses(bytes32 pauseType) external view returns (bool pauseStatus);
    function reinitializePauseTypesAndPermissions(
        address _defaultAdmin,
        IPermissionsManager.RoleAddress[] memory _roleAddresses,
        IPauseManager.PauseTypeRole[] memory _pauseTypeRoles,
        IPauseManager.PauseTypeRole[] memory _unpauseTypeRoles
    ) external;
    function remoteSender() external view returns (address);
    function removeReserved(address _token) external;
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function setCustomContract(address _nativeToken, address _targetContract) external;
    function setDeployed(address[] memory _nativeTokens) external;
    function setMessageService(address _messageService) external;
    function setRemoteTokenBridge(address _remoteTokenBridge) external;
    function setReserved(address _token) external;
    function sourceChainId() external view returns (uint256);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function targetChainId() external view returns (uint256);
    function tokenBeacon() external view returns (address);
    function unPauseByType(IPauseManager.PauseType _pauseType) external;
}
