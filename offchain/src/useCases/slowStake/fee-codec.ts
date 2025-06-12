/**
 * @fileoverview Fee Encoding/Decoding Module
 *
 * This module provides TypeScript implementations that exactly mirror the Solidity FeeCodec.sol library.
 * All encoding functions produce the same byte layout as their Solidity counterparts.
 *
 * CRITICAL: These functions must stay in sync with contracts/libraries/FeeCodec.sol
 * Any changes to the Solidity implementation must be reflected here.
 */

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
 * @throws Error if maxFee exceeds uint128 or gasLimit exceeds uint32
 */
export function encodeCCIPFee(params: CCIPFeeParams): string {
  validateCCIPParams(params);

  const maxFeeHex = params.maxFee.toString(16).padStart(32, '0');
  const payInLinkHex = params.payInLink ? '01' : '00';
  const gasLimitHex = params.gasLimit.toString(16).padStart(8, '0');

  return '0x' + maxFeeHex + payInLinkHex + gasLimitHex;
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
 */
export function encodeArbitrumL1toL2Fee(
  params: ArbitrumL1toL2FeeParams
): string {
  validateArbitrumParams(params);

  const feeAmount =
    params.maxSubmissionCost + params.gasPriceBid * BigInt(params.maxGas);

  const feeAmountHex = feeAmount.toString(16).padStart(32, '0');
  const payInLinkHex = '00'; // Always native for bridges
  const maxGasHex = params.maxGas.toString(16).padStart(8, '0');
  const gasPriceBidHex = params.gasPriceBid.toString(16).padStart(16, '0');

  return '0x' + feeAmountHex + payInLinkHex + maxGasHex + gasPriceBidHex;
}

/**
 * Encodes Optimism L1→L2 fee data exactly matching FeeCodec.encodeOptimismL1toL2
 *
 * Solidity equivalent:
 * ```solidity
 * function encodeOptimismL1toL2(uint32 l2Gas) internal pure returns (bytes memory)
 * ```
 *
 * Layout: feeAmount (16 bytes, always 0) + payInLink (1 byte, always false) + l2Gas (4 bytes) = 21 bytes
 *
 * @param params Optimism bridge fee parameters
 * @returns Encoded fee data as hex string
 */
export function encodeOptimismL1toL2Fee(
  params: OptimismL1toL2FeeParams
): string {
  validateOptimismParams(params);

  const feeAmountHex = '0'.repeat(32); // Always 0 for Optimism
  const payInLinkHex = '00'; // Always native
  const l2GasHex = params.l2Gas.toString(16).padStart(8, '0');

  return '0x' + feeAmountHex + payInLinkHex + l2GasHex;
}

/**
 * Encodes Base L1→L2 fee data exactly matching FeeCodec.encodeBaseL1toL2
 *
 * Note: Base uses the same format as Optimism
 *
 * @param params Base bridge fee parameters
 * @returns Encoded fee data as hex string
 */
export function encodeBaseL1toL2Fee(params: OptimismL1toL2FeeParams): string {
  return encodeOptimismL1toL2Fee(params);
}

// Validation functions
function validateCCIPParams(params: CCIPFeeParams): void {
  if (params.maxFee >= 2n ** 128n) {
    throw new Error('maxFee exceeds uint128 maximum');
  }
  if (params.gasLimit >= 2 ** 32) {
    throw new Error('gasLimit exceeds uint32 maximum');
  }
  if (params.gasLimit < 0) {
    throw new Error('gasLimit must be non-negative');
  }
}

function validateArbitrumParams(params: ArbitrumL1toL2FeeParams): void {
  if (params.maxSubmissionCost >= 2n ** 128n) {
    throw new Error('maxSubmissionCost exceeds uint128 maximum');
  }
  if (params.maxGas >= 2 ** 32) {
    throw new Error('maxGas exceeds uint32 maximum');
  }
  if (params.gasPriceBid >= 2n ** 64n) {
    throw new Error('gasPriceBid exceeds uint64 maximum');
  }
  if (params.maxGas < 0) {
    throw new Error('maxGas must be non-negative');
  }
}

function validateOptimismParams(params: OptimismL1toL2FeeParams): void {
  if (params.l2Gas >= 2 ** 32) {
    throw new Error('l2Gas exceeds uint32 maximum');
  }
  if (params.l2Gas < 0) {
    throw new Error('l2Gas must be non-negative');
  }
}
