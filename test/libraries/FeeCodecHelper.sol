// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "../../contracts/libraries/FeeCodec.sol";

contract FeeCodecHelper {
    function encodePackedData(address recipient, uint256 amount, bytes calldata feeData)
        public
        pure
        returns (bytes memory)
    {
        return FeeCodec.encodePackedData(recipient, amount, feeData);
    }

    function decodePackedData(bytes calldata packedData)
        public
        pure
        returns (address recipient, uint256 amount, bytes memory feeData)
    {
        return FeeCodec.decodePackedData(packedData);
    }

    function decodeFee(bytes calldata feeData) public pure returns (uint128 feeAmount, bool payInLink) {
        return FeeCodec.decodeFee(feeData);
    }

    function encodeCCIP(uint128 maxFee, bool payInLink, uint32 gasLimit) public pure returns (bytes memory) {
        return FeeCodec.encodeCCIP(maxFee, payInLink, gasLimit);
    }

    function decodeCCIP(bytes calldata feeData)
        public
        pure
        returns (uint256 feeAmount, bool payInLink, uint32 gasLimit)
    {
        return FeeCodec.decodeCCIP(feeData);
    }

    function encodeArbitrumL1toL2(uint128 maxSubmissionCost, uint32 maxGas, uint64 gasPriceBid)
        public
        pure
        returns (bytes memory)
    {
        return FeeCodec.encodeArbitrumL1toL2(maxSubmissionCost, maxGas, gasPriceBid);
    }

    function decodeArbitrumL1toL2(bytes calldata feeData)
        public
        pure
        returns (uint256 feeAmount, bool payInLink, uint256 maxSubmissionCost, uint256 maxGas, uint256 gasPriceBid)
    {
        return FeeCodec.decodeArbitrumL1toL2(feeData);
    }

    function encodeOptimismL1toL2(uint32 l2Gas) public pure returns (bytes memory) {
        return FeeCodec.encodeOptimismL1toL2(l2Gas);
    }

    function decodeOptimismL1toL2(bytes calldata feeData)
        public
        pure
        returns (uint256 feeAmount, bool payInLink, uint32 l2Gas)
    {
        return FeeCodec.decodeOptimismL1toL2(feeData);
    }

    function encodeBaseL1toL2(uint32 l2Gas) public pure returns (bytes memory) {
        return FeeCodec.encodeBaseL1toL2(l2Gas);
    }

    function decodeBaseL1toL2(bytes calldata feeData)
        public
        pure
        returns (uint256 feeAmount, bool payInLink, uint32 l2Gas)
    {
        return FeeCodec.decodeBaseL1toL2(feeData);
    }

    function encodeFraxFerryL1toL2() public pure returns (bytes memory) {
        return FeeCodec.encodeFraxFerryL1toL2();
    }

    function decodeFraxFerryL1toL2(bytes calldata feeData) public pure returns (uint256 feeAmount, bool payInLink) {
        return FeeCodec.decodeFraxFerryL1toL2(feeData);
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
