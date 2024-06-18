// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract MockCCIPRouter {
    IERC20 public immutable LINK_TOKEN;

    bytes public data;
    uint256 public value;
    uint256 private _linkFee;
    uint256 private _nativeFee;

    constructor(address linkToken, uint256 linkFee, uint256 nativeFee) {
        LINK_TOKEN = IERC20(linkToken);
        _linkFee = linkFee;
        _nativeFee = nativeFee;
    }

    function getFee(uint64, Client.EVM2AnyMessage calldata message) public view returns (uint256) {
        return message.feeToken == address(LINK_TOKEN) ? _linkFee : _nativeFee;
    }

    function ccipSend(uint64 destChainSelector, Client.EVM2AnyMessage calldata message)
        external
        payable
        returns (bytes32)
    {
        uint256 fee = getFee(destChainSelector, message);

        if (message.feeToken == address(LINK_TOKEN)) {
            require(msg.value == 0, "CCIPRouter: native fee not allowed");
            LINK_TOKEN.transferFrom(msg.sender, address(this), fee);
        } else {
            require(msg.value == fee, "CCIPRouter: insufficient fee");
        }

        uint256 length = message.tokenAmounts.length;
        for (uint256 i = 0; i < length; i++) {
            Client.EVMTokenAmount calldata token = message.tokenAmounts[i];
            IERC20(token.token).transferFrom(msg.sender, address(this), token.amount);
        }

        value = msg.value;
        data = abi.encode(destChainSelector, message);

        return keccak256("test");
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
