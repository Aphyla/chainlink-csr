// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IArbitrumL1ERC20Bridgeable {
    error ErrorAccountIsZeroAddress();
    error ErrorAlreadyInitialized();
    error ErrorDepositsDisabled();
    error ErrorDepositsEnabled();
    error ErrorETHValueTooLow();
    error ErrorNoMaxSubmissionCost();
    error ErrorUnauthorizedBridge();
    error ErrorUnsupportedL1Token();
    error ErrorUnsupportedL2Token();
    error ErrorWithdrawalsDisabled();
    error ErrorWithdrawalsEnabled();
    error ErrorWrongCrossDomainSender();
    error ExtraDataNotEmpty();

    event DepositInitiated(
        address l1Token, address indexed from, address indexed to, uint256 indexed sequenceNumber, uint256 amount
    );
    event DepositsDisabled(address indexed disabler);
    event DepositsEnabled(address indexed enabler);
    event Initialized(address indexed admin);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event TxToL2(address indexed from, address indexed to, uint256 indexed seqNum, bytes data);
    event WithdrawalFinalized(
        address l1Token, address indexed from, address indexed to, uint256 indexed exitNum, uint256 amount
    );
    event WithdrawalsDisabled(address indexed disabler);
    event WithdrawalsEnabled(address indexed enabler);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function DEPOSITS_DISABLER_ROLE() external view returns (bytes32);
    function DEPOSITS_ENABLER_ROLE() external view returns (bytes32);
    function WITHDRAWALS_DISABLER_ROLE() external view returns (bytes32);
    function WITHDRAWALS_ENABLER_ROLE() external view returns (bytes32);
    function calculateL2TokenAddress(address l1Token_) external view returns (address);
    function counterpartGateway() external view returns (address);
    function disableDeposits() external;
    function disableWithdrawals() external;
    function enableDeposits() external;
    function enableWithdrawals() external;
    function finalizeInboundTransfer(address l1Token_, address from_, address to_, uint256 amount_, bytes memory)
        external;
    function getOutboundCalldata(address l1Token_, address from_, address to_, uint256 amount_, bytes memory)
        external
        pure
        returns (bytes memory);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function inbox() external view returns (address);
    function initialize(address admin_) external;
    function isDepositsEnabled() external view returns (bool);
    function isInitialized() external view returns (bool);
    function isWithdrawalsEnabled() external view returns (bool);
    function l1Token() external view returns (address);
    function l2Token() external view returns (address);
    function outboundTransfer(
        address l1Token_,
        address to_,
        uint256 amount_,
        uint256 maxGas_,
        uint256 gasPriceBid_,
        bytes memory data_
    ) external payable returns (bytes memory);
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function router() external view returns (address);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
