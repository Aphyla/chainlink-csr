// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FeeCodec Library.
 * @dev A library for encoding and decoding fee-related data.
 */
library FeeCodec {
    /* @dev Error thrown when the length of the packed data is invalid */
    error FeeCodecInvalidDataLength(uint256 length, uint256 expectedLength);

    /**
     * @dev Returns a bytes array containing the `recipient`, `amount`, and `feeData`.
     */
    function encodePackedData(address recipient, uint256 amount, bytes memory feeData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(recipient, amount, feeData);
    }

    /**
     * @dev Decodes `packedData` and returns the `recipient`, `amount`, and `feeData`.
     *
     * Requirements:
     *
     * - `packedData` must have a length of at least 128 bytes.
     */
    function decodePackedData(bytes memory packedData)
        internal
        pure
        returns (address recipient, uint256 amount, bytes memory feeData)
    {
        if (packedData.length < 128) revert FeeCodecInvalidDataLength(packedData.length, 128);
        return abi.decode(packedData, (address, uint256, bytes));
    }

    /**
     * @dev Decodes the `feeAmount` from the bytes array `feeData`.
     *
     * Requirements:
     *
     * - `feeData` must have a length of at least 32 bytes.
     */
    function decodeFee(bytes memory feeData) internal pure returns (uint256 feeAmount) {
        if (feeData.length < 32) revert FeeCodecInvalidDataLength(feeData.length, 32);
        return uint256(bytes32(feeData));
    }

    /**
     * @dev Encodes the fee data for a Cross-Chain Interoperability Protocol (CCIP) transfer.
     * The `maxFee` is the maximum fee that the recipient is willing to pay.
     * The `payInLink` flag indicates whether the fee should be paid in LINK tokens or in the native token of the source chain.
     * The `gasLimit` is the minimum amount of gas that should be used to execute the transaction on the destination chain.
     */
    function encodeCCIP(uint256 maxFee, bool payInLink, uint256 gasLimit) internal pure returns (bytes memory) {
        return abi.encode(maxFee, payInLink, gasLimit);
    }

    /**
     * @dev Decodes the fee data for a Cross-Chain Interoperability Protocol (CCIP) transfer.
     * Returns the `maxFee`, `payInLink`, and `gasLimit`.
     * The `maxFee` is the maximum fee that the recipient is willing to pay.
     * The `payInLink` flag indicates whether the fee should be paid in LINK tokens or in the native token of the source chain.
     * The `gasLimit` is the minimum amount of gas that should be used to execute the transaction on the destination chain.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 96 bytes.
     */
    function decodeCCIP(bytes memory feeData)
        internal
        pure
        returns (uint256 maxFee, bool payInLink, uint256 gasLimit)
    {
        if (feeData.length != 96) revert FeeCodecInvalidDataLength(feeData.length, 96);
        return abi.decode(feeData, (uint256, bool, uint256));
    }

    /**
     * @dev Encodes the fee data for an Arbitrum L1-to-L2 transfer.
     * The `maxSubmissionCost` is the base submission cost for the L2 retryable ticket.
     * The `maxGas` is the maximum amount of gas for the L2 retryable ticket.
     * The `gasPriceBid` is the gas price bid for the L2 retryable ticket.
     */
    function encodeArbitrumL1toL2(uint256 maxSubmissionCost, uint256 maxGas, uint256 gasPriceBid)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(maxSubmissionCost + gasPriceBid * maxGas, maxSubmissionCost, maxGas, gasPriceBid);
    }

    /**
     * @dev Decodes the fee data for an Arbitrum L1-to-L2 transfer.
     * Returns the `feeAmount`, `maxSubmissionCost`, `maxGas`, and `gasPriceBid`.
     * The `feeAmount` is the total fee amount for the transfer (`maxSubmissionCost` + `gasPriceBid` * `maxGas`).
     * The `maxSubmissionCost` is the base submission cost for the L2 retryable ticket.
     * The `maxGas` is the maximum amount of gas for the L2 retryable ticket.
     * The `gasPriceBid` is the gas price bid for the L2 retryable ticket.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 128 bytes.
     */
    function decodeArbitrumL1toL2(bytes memory feeData)
        internal
        pure
        returns (uint256 feeAmount, uint256 maxSubmissionCost, uint256 maxGas, uint256 gasPriceBid)
    {
        if (feeData.length != 128) revert FeeCodecInvalidDataLength(feeData.length, 128);
        return abi.decode(feeData, (uint256, uint256, uint256, uint256));
    }

    /**
     * @dev Encodes the fee data for an Optimism L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     */
    function encodeOptimismL1toL2(uint32 l2Gas) internal pure returns (bytes memory) {
        return abi.encode(0, l2Gas);
    }

    /**
     * @dev Decodes the fee data for an Optimism L1-to-L2 transfer.
     * Returns the `feeAmount` and `l2Gas`.
     * The `feeAmount` is always zero for an Optimism L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 64 bytes.
     */
    function decodeOptimismL1toL2(bytes memory feeData) internal pure returns (uint256 feeAmount, uint32 l2Gas) {
        if (feeData.length != 64) revert FeeCodecInvalidDataLength(feeData.length, 64);
        return abi.decode(feeData, (uint256, uint32));
    }

    /**
     * @dev Encodes the fee data for a Base L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     */
    function encodeBaseL1toL2(uint32 l2Gas) internal pure returns (bytes memory) {
        return abi.encode(0, l2Gas);
    }

    /**
     * @dev Decodes the fee data for a Base L1-to-L2 transfer.
     * Returns the `feeAmount` and `l2Gas`.
     * The `feeAmount` is always zero for a Base L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 64 bytes.
     */
    function decodeBaseL1toL2(bytes memory feeData) internal pure returns (uint256 feeAmount, uint32 l2Gas) {
        if (feeData.length != 64) revert FeeCodecInvalidDataLength(feeData.length, 64);
        return abi.decode(feeData, (uint256, uint32));
    }

    /**
     * @dev Encodes the fee data for a Frax Ferry L1-to-L2 transfer.
     */
    function encodeFraxFerryL1toL2() internal pure returns (bytes memory) {
        return abi.encode(0);
    }

    /**
     * @dev Decodes the fee data for a Frax Ferry L1-to-L2 transfer.
     * Returns the `feeAmount`.
     * The `feeAmount` is always zero for a Frax Ferry L1-to-L2 transfer.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 32 bytes.
     */
    function decodeFraxFerryL1toL2(bytes memory feeData) internal pure returns (uint256 feeAmount) {
        if (feeData.length != 32) revert FeeCodecInvalidDataLength(feeData.length, 32);
        return abi.decode(feeData, (uint256));
    }
}
