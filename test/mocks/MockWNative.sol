// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWNative} from "../../contracts/interfaces/IWNative.sol";

contract MockWNative is ERC20, IWNative {
    constructor() ERC20("Wrapped Native", "WNative") {}

    function deposit() external payable override {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        _burn(msg.sender, amount);
        (bool success,) = msg.sender.call{value: amount}(new bytes(0));
        require(success, "withdraw failed");
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
