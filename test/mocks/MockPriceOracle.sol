// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract MockPriceOracle {
    uint256 public _latestAnswer;

    function getLatestAnswer() public view returns (uint256) {
        return _latestAnswer;
    }

    function setLatestAnswer(uint256 latestAnswer) public {
        _latestAnswer = latestAnswer;
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
