// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOptimismL1ERC20TokenBridge {
    error ErrorAccountIsZeroAddress();
    error ErrorAlreadyInitialized();
    error ErrorBridgingManagerIsNotInitialized();
    error ErrorDepositsDisabled();
    error ErrorDepositsEnabled();
    error ErrorSenderNotEOA();
    error ErrorUnauthorizedMessenger();
    error ErrorUnsupportedL1L2TokensPair(address l1Token, address l2Token);
    error ErrorUnsupportedL2Token(address l2Token);
    error ErrorWithdrawalsDisabled();
    error ErrorWithdrawalsEnabled();
    error ErrorWrongCrossDomainSender();
    error ErrorZeroAddressAccountingOracle();
    error ErrorZeroAddressAdmin();
    error ErrorZeroAddressL1TokenNonRebasable();
    error ErrorZeroAddressL1TokenRebasable();
    error ErrorZeroAddressL2Bridge();
    error ErrorZeroAddressL2TokenNonRebasable();
    error ErrorZeroAddressL2TokenRebasable();
    error ErrorZeroAddressMessenger();
    error ErrorZeroAddressWstETH();
    error InvalidContractVersionIncrement();
    error NonZeroContractVersionOnInit();
    error UnexpectedContractVersion(uint256 expected, uint256 received);

    event ContractVersionSet(uint256 version);
    event DepositsDisabled(address indexed disabler);
    event DepositsEnabled(address indexed enabler);
    event ERC20DepositInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );
    event ERC20WithdrawalFinalized(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );
    event Initialized(address indexed admin);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event WithdrawalsDisabled(address indexed disabler);
    event WithdrawalsEnabled(address indexed enabler);

    function ACCOUNTING_ORACLE() external view returns (address);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function DEPOSITS_DISABLER_ROLE() external view returns (bytes32);
    function DEPOSITS_ENABLER_ROLE() external view returns (bytes32);
    function GENESIS_TIME() external view returns (uint256);
    function L1_TOKEN_NON_REBASABLE() external view returns (address);
    function L1_TOKEN_REBASABLE() external view returns (address);
    function L2_TOKEN_NON_REBASABLE() external view returns (address);
    function L2_TOKEN_REBASABLE() external view returns (address);
    function MESSENGER() external view returns (address);
    function SECONDS_PER_SLOT() external view returns (uint256);
    function TOKEN_RATE_DECIMALS() external view returns (uint256);
    function WITHDRAWALS_DISABLER_ROLE() external view returns (bytes32);
    function WITHDRAWALS_ENABLER_ROLE() external view returns (bytes32);
    function WSTETH() external view returns (address);
    function depositERC20(address l1Token_, address l2Token_, uint256 amount_, uint32 l2Gas_, bytes memory data_)
        external;
    function depositERC20To(
        address l1Token_,
        address l2Token_,
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes memory data_
    ) external;
    function disableDeposits() external;
    function disableWithdrawals() external;
    function enableDeposits() external;
    function enableWithdrawals() external;
    function finalizeERC20Withdrawal(
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes memory data_
    ) external;
    function finalizeUpgrade_v2() external;
    function getContractVersion() external view returns (uint256);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function initialize(address admin_) external;
    function isDepositsEnabled() external view returns (bool);
    function isInitialized() external view returns (bool);
    function isWithdrawalsEnabled() external view returns (bool);
    function l2TokenBridge() external view returns (address);
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
