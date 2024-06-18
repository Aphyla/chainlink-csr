// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library FeeCodec {
    error FeeCodecInvalidDataLength(uint256 length, uint256 expectedLength);

    function encodePackedData(address recipient, uint256 amount, bytes memory feeData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(recipient, amount, feeData);
    }

    function decodePackedData(bytes memory packedData)
        internal
        pure
        returns (address recipient, uint256 amount, bytes memory feeData)
    {
        if (packedData.length < 128) revert FeeCodecInvalidDataLength(packedData.length, 128);
        return abi.decode(packedData, (address, uint256, bytes));
    }

    function decodeFee(bytes memory feeData) internal pure returns (uint256 feeAmount) {
        if (feeData.length < 32) revert FeeCodecInvalidDataLength(feeData.length, 32);
        return uint256(bytes32(feeData));
    }

    function encodeCCIP(uint256 maxFee, bool payInLink, uint256 gasLimit) internal pure returns (bytes memory) {
        return abi.encode(maxFee, payInLink, gasLimit);
    }

    function decodeCCIP(bytes memory feeData)
        internal
        pure
        returns (uint256 maxFee, bool payInLink, uint256 gasLimit)
    {
        if (feeData.length != 96) revert FeeCodecInvalidDataLength(feeData.length, 96);
        return abi.decode(feeData, (uint256, bool, uint256));
    }

    function encodeArbitrumL1toL2(uint256 maxSubmissionCost, uint256 maxGas, uint256 gasPriceBid)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(maxSubmissionCost + gasPriceBid * maxGas, maxSubmissionCost, maxGas, gasPriceBid);
    }

    function decodeArbitrumL1toL2(bytes memory feeData)
        internal
        pure
        returns (uint256 feeAmount, uint256 maxSubmissionCost, uint256 maxGas, uint256 gasPriceBid)
    {
        if (feeData.length != 128) revert FeeCodecInvalidDataLength(feeData.length, 128);
        return abi.decode(feeData, (uint256, uint256, uint256, uint256));
    }

    function encodeOptimismL1toL2(uint32 l2Gas) internal pure returns (bytes memory) {
        return abi.encode(0, l2Gas);
    }

    function decodeOptimismL1toL2(bytes memory feeData) internal pure returns (uint256 feeAmount, uint32 l2Gas) {
        if (feeData.length != 64) revert FeeCodecInvalidDataLength(feeData.length, 64);
        return abi.decode(feeData, (uint256, uint32));
    }
}
