/**
 * @fileoverview Fee Encoding/Decoding Module
 *
 * This module provides TypeScript implementations that exactly mirror the Solidity FeeCodec.sol library.
 * All encoding functions produce the same byte layout as their Solidity counterparts.
 *
 * CRITICAL: These functions must stay in sync with contracts/libraries/FeeCodec.sol
 * Any changes to the Solidity implementation must be reflected here.
 */

import { toBeHex, zeroPadValue, concat, hexlify } from 'ethers';

/**
 * CCIP fee parameters for encoding
 */
export interface CCIPFeeParams {
  readonly maxFee: bigint;
  readonly payInLink: boolean;
  readonly gasLimit: number;
}

/**
 * Arbitrum L1→L2 bridge fee parameters
 */
export interface ArbitrumL1toL2FeeParams {
  readonly maxSubmissionCost: bigint;
  readonly maxGas: number;
  readonly gasPriceBid: bigint;
}

/**
 * Optimism/Base L1→L2 bridge fee parameters
 */
export interface OptimismL1toL2FeeParams {
  readonly l2Gas: number;
}

/**
 * Generic fee parameters (for basic bridges)
 */
export interface GenericFeeParams {
  readonly feeAmount: bigint;
  readonly payInLink: boolean;
}

// Constants for validation
const UINT32_MAX = 0xffffffff;
const UINT64_MAX = 0xffffffffffffffffn;
const UINT128_MAX = 0xffffffffffffffffffffffffffffffffn;

/**
 * Encodes CCIP fee data exactly matching FeeCodec.encodeCCIP
 *
 * Solidity equivalent:
 * ```solidity
 * function encodeCCIP(uint128 maxFee, bool payInLink, uint32 gasLimit)
 *   internal pure returns (bytes memory)
 * ```
 *
 * Layout: maxFee (16 bytes) + payInLink (1 byte) + gasLimit (4 bytes) = 21 bytes
 *
 * @param params CCIP fee parameters
 * @returns Encoded fee data as hex string
 * @throws Error if parameters exceed their respective type bounds
 */
export function encodeCCIPFee(params: CCIPFeeParams): string {
  validateCCIPParams(params);

  return hexlify(
    concat([
      zeroPadValue(toBeHex(params.maxFee), 16), // uint128 (16 bytes)
      toBeHex(params.payInLink ? 1 : 0, 1), // bool as uint8 (1 byte)
      zeroPadValue(toBeHex(params.gasLimit), 4), // uint32 (4 bytes)
    ])
  );
}

/**
 * Encodes Arbitrum L1→L2 fee data exactly matching FeeCodec.encodeArbitrumL1toL2
 *
 * Solidity equivalent:
 * ```solidity
 * function encodeArbitrumL1toL2(uint128 maxSubmissionCost, uint32 maxGas, uint64 gasPriceBid)
 *   internal pure returns (bytes memory)
 * ```
 *
 * Layout: feeAmount (16 bytes) + payInLink (1 byte) + maxGas (4 bytes) + gasPriceBid (8 bytes) = 29 bytes
 * where feeAmount = maxSubmissionCost + gasPriceBid * maxGas
 *
 * @param params Arbitrum bridge fee parameters
 * @returns Encoded fee data as hex string
 * @throws Error if parameters exceed their respective type bounds or if feeAmount overflows
 */
export function encodeArbitrumL1toL2Fee(
  params: ArbitrumL1toL2FeeParams
): string {
  validateArbitrumParams(params);

  // Calculate feeAmount exactly as Solidity does
  const feeAmount =
    params.maxSubmissionCost + params.gasPriceBid * BigInt(params.maxGas);

  // Validate that feeAmount doesn't overflow uint128
  if (feeAmount > UINT128_MAX) {
    throw new Error(
      `Calculated feeAmount (${feeAmount}) exceeds uint128 maximum`
    );
  }

  return hexlify(
    concat([
      zeroPadValue(toBeHex(feeAmount), 16), // uint128 feeAmount (16 bytes)
      toBeHex(0, 1), // uint8 payInLink = false (1 byte)
      zeroPadValue(toBeHex(params.maxGas), 4), // uint32 maxGas (4 bytes)
      zeroPadValue(toBeHex(params.gasPriceBid), 8), // uint64 gasPriceBid (8 bytes)
    ])
  );
}

/**
 * Encodes Optimism L1→L2 fee data exactly matching FeeCodec.encodeOptimismL1toL2
 *
 * Solidity equivalent:
 * ```solidity
 * function encodeOptimismL1toL2(uint32 l2Gas) internal pure returns (bytes memory) {
 *     return abi.encodePacked(uint136(0), l2Gas);
 * }
 * ```
 *
 * Layout: uint136(0) + l2Gas (uint32) = 17 + 4 = 21 bytes
 * Note: We encode this as feeAmount(16) + payInLink(1) + l2Gas(4) which produces identical bytes
 *
 * @param params Optimism bridge fee parameters
 * @returns Encoded fee data as hex string
 * @throws Error if l2Gas exceeds uint32 bounds
 */
export function encodeOptimismL1toL2Fee(
  params: OptimismL1toL2FeeParams
): string {
  validateOptimismParams(params);

  // This produces identical bytes to abi.encodePacked(uint136(0), l2Gas)
  return hexlify(
    concat([
      zeroPadValue(toBeHex(0), 16), // feeAmount = 0 (16 bytes)
      toBeHex(0, 1), // payInLink = false (1 byte)
      zeroPadValue(toBeHex(params.l2Gas), 4), // uint32 l2Gas (4 bytes)
    ])
  );
}

/**
 * Encodes Base L1→L2 fee data exactly matching FeeCodec.encodeBaseL1toL2
 *
 * Solidity equivalent:
 * ```solidity
 * function encodeBaseL1toL2(uint32 l2Gas) internal pure returns (bytes memory) {
 *     return abi.encodePacked(uint136(0), l2Gas);
 * }
 * ```
 *
 * Note: Base uses the same format as Optimism
 *
 * @param params Base bridge fee parameters
 * @returns Encoded fee data as hex string
 */
export function encodeBaseL1toL2Fee(params: OptimismL1toL2FeeParams): string {
  return encodeOptimismL1toL2Fee(params);
}

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

/**
 * Validates CCIP fee parameters
 * @param params Parameters to validate
 * @throws Error if parameters are invalid
 */
export function validateCCIPParams(params: CCIPFeeParams): void {
  if (!isValidCCIPParams(params)) {
    throw new Error('Invalid CCIP parameters structure');
  }

  if (params.maxFee > UINT128_MAX) {
    throw new Error(`maxFee (${params.maxFee}) exceeds uint128 maximum`);
  }

  if (params.gasLimit > UINT32_MAX) {
    throw new Error(`gasLimit (${params.gasLimit}) exceeds uint32 maximum`);
  }

  if (params.gasLimit < 0) {
    throw new Error('gasLimit must be non-negative');
  }
}

/**
 * Validates Arbitrum fee parameters
 * @param params Parameters to validate
 * @throws Error if parameters are invalid
 */
export function validateArbitrumParams(params: ArbitrumL1toL2FeeParams): void {
  if (!isValidArbitrumParams(params)) {
    throw new Error('Invalid Arbitrum parameters structure');
  }

  if (params.maxSubmissionCost > UINT128_MAX) {
    throw new Error(
      `maxSubmissionCost (${params.maxSubmissionCost}) exceeds uint128 maximum`
    );
  }

  if (params.maxGas > UINT32_MAX) {
    throw new Error(`maxGas (${params.maxGas}) exceeds uint32 maximum`);
  }

  if (params.gasPriceBid > UINT64_MAX) {
    throw new Error(
      `gasPriceBid (${params.gasPriceBid}) exceeds uint64 maximum`
    );
  }

  if (params.maxGas < 0) {
    throw new Error('maxGas must be non-negative');
  }

  if (params.maxSubmissionCost < 0n) {
    throw new Error('maxSubmissionCost must be non-negative');
  }

  if (params.gasPriceBid < 0n) {
    throw new Error('gasPriceBid must be non-negative');
  }
}

/**
 * Validates Optimism fee parameters
 * @param params Parameters to validate
 * @throws Error if parameters are invalid
 */
export function validateOptimismParams(params: OptimismL1toL2FeeParams): void {
  if (!isValidOptimismParams(params)) {
    throw new Error('Invalid Optimism parameters structure');
  }

  if (params.l2Gas > UINT32_MAX) {
    throw new Error(`l2Gas (${params.l2Gas}) exceeds uint32 maximum`);
  }

  if (params.l2Gas < 0) {
    throw new Error('l2Gas must be non-negative');
  }
}

// ============================================================================
// TYPE GUARDS
// ============================================================================

/**
 * Type guard for CCIP fee parameters
 * @param params Object to validate
 * @returns True if params is a valid CCIPFeeParams object
 */
export function isValidCCIPParams(params: unknown): params is CCIPFeeParams {
  return (
    typeof params === 'object' &&
    params !== null &&
    typeof (params as Record<string, unknown>).maxFee === 'bigint' &&
    typeof (params as Record<string, unknown>).payInLink === 'boolean' &&
    typeof (params as Record<string, unknown>).gasLimit === 'number'
  );
}

/**
 * Type guard for Arbitrum fee parameters
 * @param params Object to validate
 * @returns True if params is a valid ArbitrumL1toL2FeeParams object
 */
export function isValidArbitrumParams(
  params: unknown
): params is ArbitrumL1toL2FeeParams {
  return (
    typeof params === 'object' &&
    params !== null &&
    typeof (params as Record<string, unknown>).maxSubmissionCost === 'bigint' &&
    typeof (params as Record<string, unknown>).maxGas === 'number' &&
    typeof (params as Record<string, unknown>).gasPriceBid === 'bigint'
  );
}

/**
 * Type guard for Optimism/Base fee parameters
 * @param params Object to validate
 * @returns True if params is a valid OptimismL1toL2FeeParams object
 */
export function isValidOptimismParams(
  params: unknown
): params is OptimismL1toL2FeeParams {
  return (
    typeof params === 'object' &&
    params !== null &&
    typeof (params as Record<string, unknown>).l2Gas === 'number'
  );
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Calculates the total fee for Arbitrum without encoding
 * Useful for fee estimation before encoding
 *
 * @param params Arbitrum fee parameters
 * @returns Calculated fee amount
 */
export function calculateArbitrumFeeAmount(
  params: ArbitrumL1toL2FeeParams
): bigint {
  validateArbitrumParams(params);
  const feeAmount =
    params.maxSubmissionCost + params.gasPriceBid * BigInt(params.maxGas);

  if (feeAmount > UINT128_MAX) {
    throw new Error(
      `Calculated feeAmount (${feeAmount}) exceeds uint128 maximum`
    );
  }

  return feeAmount;
}

/**
 * Gets the byte length for each bridge type
 * @param bridgeType The type of bridge
 * @returns Expected byte length of encoded fee data
 */
export function getExpectedByteLength(
  bridgeType: 'ccip' | 'arbitrum' | 'optimism' | 'base'
): number {
  switch (bridgeType) {
    case 'ccip':
      return 21;
    case 'arbitrum':
      return 29;
    case 'optimism':
    case 'base':
      return 21;
    default:
      throw new Error(`Unknown bridge type: ${bridgeType}`);
  }
}
