// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IArbitrumL1GatewayRouter {
    event DefaultGatewayUpdated(address newDefaultGateway);
    event GatewaySet(address indexed l1Token, address indexed gateway);
    event TransferRouted(address indexed token, address indexed _userFrom, address indexed _userTo, address gateway);
    event TxToL2(address indexed _from, address indexed _to, uint256 indexed _seqNum, bytes _data);
    event WhitelistSourceUpdated(address newSource);

    function calculateL2TokenAddress(address l1ERC20) external view returns (address);
    function counterpartGateway() external view returns (address);
    function defaultGateway() external view returns (address);
    function finalizeInboundTransfer(address, address, address, uint256, bytes memory) external payable;
    function getGateway(address _token) external view returns (address gateway);
    function getOutboundCalldata(address _token, address _from, address _to, uint256 _amount, bytes memory _data)
        external
        view
        returns (bytes memory);
    function inbox() external view returns (address);
    function initialize(address _owner, address _defaultGateway, address, address _counterpartGateway, address _inbox)
        external;
    function l1TokenToGateway(address) external view returns (address);
    function outboundTransfer(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        bytes memory _data
    ) external payable returns (bytes memory);
    function outboundTransferCustomRefund(
        address _token,
        address _refundTo,
        address _to,
        uint256 _amount,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        bytes memory _data
    ) external payable returns (bytes memory);
    function owner() external view returns (address);
    function postUpgradeInit() external;
    function router() external view returns (address);
    function setDefaultGateway(
        address newL1DefaultGateway,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        uint256 _maxSubmissionCost
    ) external payable returns (uint256);
    function setGateway(
        address _gateway,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        uint256 _maxSubmissionCost,
        address _creditBackAddress
    ) external payable returns (uint256);
    function setGateway(address _gateway, uint256 _maxGas, uint256 _gasPriceBid, uint256 _maxSubmissionCost)
        external
        payable
        returns (uint256);
    function setGateways(
        address[] memory _token,
        address[] memory _gateway,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        uint256 _maxSubmissionCost
    ) external payable returns (uint256);
    function setOwner(address newOwner) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function updateWhitelistSource(address newSource) external;
    function whitelist() external view returns (address);
}
