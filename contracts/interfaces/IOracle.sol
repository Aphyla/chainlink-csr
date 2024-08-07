// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracle {
    function getLatestAnswer() external view returns (uint256);
}
