// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {BridgeAdapter} from "../../contracts/adapters/BridgeAdapter.sol";

contract MockReceiver {
    address public adapter;

    function setAdapter(address adapter_) public {
        adapter = adapter_;
    }

    function sendToken(uint64 destChainSelector, address to, uint256 amount, bytes memory feeData) external {
        Address.functionDelegateCall(
            adapter, abi.encodeWithSelector(BridgeAdapter.sendToken.selector, destChainSelector, to, amount, feeData)
        );
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
