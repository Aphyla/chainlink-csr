// SPDX-License-Identifier: Apache-2.0
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
    function encodePackedData(address recipient, uint256 amount, bytes calldata feeData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(recipient, amount, feeData);
    }

    /**
     * @dev Returns a bytes array containing the `recipient`, `amount`, and `feeData`.
     */
    function encodePackedDataMemory(address recipient, uint256 amount, bytes memory feeData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(recipient, amount, feeData);
    }

    /**
     * @dev Decodes `packedData` and returns the `recipient`, `amount`, and `feeData`.
     *
     * Requirements:
     *
     * - `packedData` must have a length of at least 52 bytes.
     */
    function decodePackedData(bytes calldata packedData)
        internal
        pure
        returns (address recipient, uint256 amount, bytes calldata feeData)
    {
        if (packedData.length < 52) revert FeeCodecInvalidDataLength(packedData.length, 52);

        recipient = address(uint160(bytes20(packedData[0:20])));
        amount = uint256(bytes32(packedData[20:52]));
        feeData = packedData[52:];
    }

    /**
     * @dev Decodes `packedData` and returns the `recipient`, `amount`, and `feeData`.
     *
     * Requirements:
     *
     * - `packedData` must have a length of at least 52 bytes.
     */
    function decodePackedDataMemory(bytes memory packedData)
        internal
        pure
        returns (address recipient, uint256 amount, bytes memory feeData)
    {
        uint256 length = packedData.length;

        if (length < 52) revert FeeCodecInvalidDataLength(packedData.length, 52);

        feeData = abi.encodePacked(packedData); // Force solidity to copy the data

        assembly {
            recipient := shr(96, mload(add(packedData, 0x20)))
            amount := mload(add(packedData, 0x34))

            feeData := add(packedData, 0x34)
            mstore(feeData, sub(length, 0x34))
        }
    }

    /**
     * @dev Decodes the `feeAmount` and `payInLink` from the bytes array `feeData`.
     *
     * Requirements:
     *
     * - `feeData` must have a length of at least 17 bytes.
     */
    function decodeFee(bytes calldata feeData) internal pure returns (uint128 feeAmount, bool payInLink) {
        if (feeData.length < 17) revert FeeCodecInvalidDataLength(feeData.length, 17);
        return (uint128(bytes16(feeData[0:16])), feeData[16] != 0);
    }

    /**
     * @dev Decodes the `feeAmount` and `payInLink` from the bytes array `feeData`.
     *
     * Requirements:
     *
     * - `feeData` must have a length of at least 17 bytes.
     */
    function decodeFeeMemory(bytes memory feeData) internal pure returns (uint128 feeAmount, bool payInLink) {
        if (feeData.length < 17) revert FeeCodecInvalidDataLength(feeData.length, 17);
        bytes32 value = bytes32(feeData);

        feeAmount = uint128(bytes16(value));
        payInLink = (uint256(value) >> 120) & 0xff != 0;
    }

    /**
     * @dev Encodes the fee data for a Cross-Chain Interoperability Protocol (CCIP) transfer.
     * The `maxFee` is the maximum fee that the recipient is willing to pay.
     * The `payInLink` flag indicates whether the fee should be paid in LINK tokens or in the native token of the source chain.
     * The `gasLimit` is the minimum amount of gas that should be used to execute the transaction on the destination chain.
     */
    function encodeCCIP(uint128 maxFee, bool payInLink, uint32 gasLimit) internal pure returns (bytes memory) {
        return abi.encodePacked(maxFee, payInLink, gasLimit);
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
     * - `feeData` must have a length of 21 bytes.
     */
    function decodeCCIP(bytes calldata feeData)
        internal
        pure
        returns (uint128 maxFee, bool payInLink, uint32 gasLimit)
    {
        if (feeData.length != 21) revert FeeCodecInvalidDataLength(feeData.length, 21);
        maxFee = uint128(bytes16(feeData[0:16]));
        payInLink = feeData[16] != 0;
        gasLimit = uint32(bytes4(feeData[17:21]));
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
     * - `feeData` must have a length of 21 bytes.
     */
    function decodeCCIPMemory(bytes memory feeData)
        internal
        pure
        returns (uint128 maxFee, bool payInLink, uint32 gasLimit)
    {
        if (feeData.length < 21) revert FeeCodecInvalidDataLength(feeData.length, 21);
        bytes32 value = bytes32(feeData);

        maxFee = uint128(bytes16(value));
        payInLink = uint8(uint256(value) >> 120) != 0;
        gasLimit = uint32(uint256(value) >> 88);
    }

    /**
     * @dev Encodes the fee data for an Arbitrum L1-to-L2 transfer.
     * The `maxSubmissionCost` is the base submission cost for the L2 retryable ticket.
     * The `maxGas` is the maximum amount of gas for the L2 retryable ticket.
     * The `gasPriceBid` is the gas price bid for the L2 retryable ticket.
     */
    function encodeArbitrumL1toL2(uint128 maxSubmissionCost, uint32 maxGas, uint64 gasPriceBid)
        internal
        pure
        returns (bytes memory)
    {
        uint128 feeAmount = maxSubmissionCost + uint128(gasPriceBid) * maxGas;
        return abi.encodePacked(feeAmount, uint8(0), maxGas, gasPriceBid);
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
     * - `feeData` must have a length of 29 bytes.
     */
    function decodeArbitrumL1toL2(bytes calldata feeData)
        internal
        pure
        returns (uint128 feeAmount, bool payInLink, uint128 maxSubmissionCost, uint32 maxGas, uint64 gasPriceBid)
    {
        if (feeData.length != 29) revert FeeCodecInvalidDataLength(feeData.length, 29);
        feeAmount = uint128(bytes16(feeData[0:16]));
        payInLink = feeData[16] != 0;
        maxGas = uint32(bytes4(feeData[17:21]));
        gasPriceBid = uint64(bytes8(feeData[21:29]));

        maxSubmissionCost = feeAmount - uint128(gasPriceBid) * maxGas;
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
     * - `feeData` must have a length of 29 bytes.
     */
    function decodeArbitrumL1toL2Memory(bytes memory feeData)
        internal
        pure
        returns (uint128 feeAmount, bool payInLink, uint128 maxSubmissionCost, uint32 maxGas, uint64 gasPriceBid)
    {
        if (feeData.length != 29) revert FeeCodecInvalidDataLength(feeData.length, 29);
        bytes32 value = bytes32(feeData);

        feeAmount = uint128(bytes16(value));
        payInLink = uint8(uint256(value) >> 120) != 0;
        maxGas = uint32(uint256(value) >> 88);
        gasPriceBid = uint64(uint256(value) >> 24);

        maxSubmissionCost = feeAmount - uint128(gasPriceBid) * maxGas;
    }

    /**
     * @dev Encodes the fee data for an Optimism L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     */
    function encodeOptimismL1toL2(uint32 l2Gas) internal pure returns (bytes memory) {
        return abi.encodePacked(uint136(0), l2Gas);
    }

    /**
     * @dev Decodes the fee data for an Optimism L1-to-L2 transfer.
     * Returns the `feeAmount` and `l2Gas`.
     * The `feeAmount` is always zero for an Optimism L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 21 bytes.
     */
    function decodeOptimismL1toL2(bytes calldata feeData)
        internal
        pure
        returns (uint128 feeAmount, bool payInLink, uint32 l2Gas)
    {
        if (feeData.length != 21) revert FeeCodecInvalidDataLength(feeData.length, 21);
        feeAmount = uint128(bytes16(feeData[0:16]));
        payInLink = feeData[16] != 0;
        l2Gas = uint32(bytes4(feeData[17:21]));
    }

    /**
     * @dev Decodes the fee data for an Optimism L1-to-L2 transfer.
     * Returns the `feeAmount` and `l2Gas`.
     * The `feeAmount` is always zero for an Optimism L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 21 bytes.
     */
    function decodeOptimismL1toL2Memory(bytes memory feeData)
        internal
        pure
        returns (uint128 feeAmount, bool payInLink, uint32 l2Gas)
    {
        if (feeData.length != 21) revert FeeCodecInvalidDataLength(feeData.length, 21);
        bytes32 value = bytes32(feeData);

        feeAmount = uint128(bytes16(value));
        payInLink = uint8(uint256(value) >> 120) != 0;
        l2Gas = uint32(uint256(value) >> 88);
    }

    /**
     * @dev Encodes the fee data for a Base L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     */
    function encodeBaseL1toL2(uint32 l2Gas) internal pure returns (bytes memory) {
        return abi.encodePacked(uint136(0), l2Gas);
    }

    /**
     * @dev Decodes the fee data for a Base L1-to-L2 transfer.
     * Returns the `feeAmount` and `l2Gas`.
     * The `feeAmount` is always zero for a Base L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 21 bytes.
     */
    function decodeBaseL1toL2(bytes calldata feeData)
        internal
        pure
        returns (uint128 feeAmount, bool payInLink, uint32 l2Gas)
    {
        if (feeData.length != 21) revert FeeCodecInvalidDataLength(feeData.length, 21);
        feeAmount = uint128(bytes16(feeData[0:16]));
        payInLink = feeData[16] != 0;
        l2Gas = uint32(bytes4(feeData[17:21]));
    }

    /**
     * @dev Decodes the fee data for a Base L1-to-L2 transfer.
     * Returns the `feeAmount` and `l2Gas`.
     * The `feeAmount` is always zero for a Base L1-to-L2 transfer.
     * The `l2Gas` is the minimum amount of gas that should be used for the deposit message on L2.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 21 bytes.
     */
    function decodeBaseL1toL2Memory(bytes memory feeData)
        internal
        pure
        returns (uint128 feeAmount, bool payInLink, uint32 l2Gas)
    {
        if (feeData.length != 21) revert FeeCodecInvalidDataLength(feeData.length, 21);
        bytes32 value = bytes32(feeData);

        feeAmount = uint128(bytes16(value));
        payInLink = uint8(uint256(value) >> 120) != 0;
        l2Gas = uint32(uint256(value) >> 88);
    }

    /**
     * @dev Encodes the fee data for a Frax Ferry L1-to-L2 transfer.
     */
    function encodeFraxFerryL1toL2() internal pure returns (bytes memory) {
        return abi.encodePacked(uint136(0));
    }

    /**
     * @dev Decodes the fee data for a Frax Ferry L1-to-L2 transfer.
     * Returns the `feeAmount`.
     * The `feeAmount` is always zero for a Frax Ferry L1-to-L2 transfer.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 17 bytes.
     */
    function decodeFraxFerryL1toL2(bytes calldata feeData) internal pure returns (uint128 feeAmount, bool payInLink) {
        if (feeData.length != 17) revert FeeCodecInvalidDataLength(feeData.length, 17);
        feeAmount = uint128(bytes16(feeData[0:16]));
        payInLink = feeData[16] != 0;
    }

    /**
     * @dev Decodes the fee data for a Frax Ferry L1-to-L2 transfer.
     * Returns the `feeAmount`.
     * The `feeAmount` is always zero for a Frax Ferry L1-to-L2 transfer.
     *
     * Requirements:
     *
     * - `feeData` must have a length of 17 bytes.
     */
    function decodeFraxFerryL1toL2Memory(bytes memory feeData)
        internal
        pure
        returns (uint128 feeAmount, bool payInLink)
    {
        if (feeData.length != 17) revert FeeCodecInvalidDataLength(feeData.length, 17);
        bytes32 value = bytes32(feeData);

        feeAmount = uint128(bytes16(value));
        payInLink = uint8(uint256(value) >> 120) != 0;
    }
}
