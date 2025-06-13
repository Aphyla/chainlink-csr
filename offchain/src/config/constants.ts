/**
 * Application-wide constants for the Chainlink CSR Framework.
 *
 * This module contains shared constants used across the application
 * to ensure consistency and provide a single source of truth.
 */

import { parseEther } from 'ethers';

/**
 * Transaction Configuration
 */

/**
 * Number of block confirmations to wait for transaction finality.
 * This setting balances security vs speed for transaction confirmations.
 */
export const NUMBER_BLOCKS_TO_WAIT = 3;

/**
 * Default Values
 */

/**
 * Default slippage tolerance for operations (1%).
 * Matches the SlippageTolerance type from types.ts.
 */
export const DEFAULT_SLIPPAGE_TOLERANCE = 0.01;

/**
 * Testing amounts in wei for examples and testing.
 * These provide consistent, safe amounts for demonstration purposes.
 */
export const TESTING_AMOUNTS = {
  /** Very small amount for basic testing (0.0001 ETH) */
  TINY: parseEther('0.0001'),
  /** Small amount for testing (0.001 ETH) */
  SMALL: parseEther('0.001'),
  /** Standard test amount (0.01 ETH) */
  STANDARD: parseEther('0.01'),
  /** Larger test amount (0.1 ETH) */
  LARGE: parseEther('0.1'),
  /** Large amount for testing (1 ETH) */
  XLARGE: parseEther('1'),
} as const;

/**
 * SlowStake Configuration
 */

/**
 * Gas limit multiplier for CCIP operations.
 * The contract defines MIN_PROCESS_MESSAGE_GAS = 75,000 as minimum.
 * Standard operations use 1,000,000 gas (75,000 * 13.33 ≈ 1,000,000).
 */
export const SLOWSTAKE_GAS_LIMIT_MULTIPLIER = 13;

/**
 * Fee buffer configuration for CCIP fee estimation.
 * Applied to router estimates to account for fee fluctuations between
 * estimation and execution (10% buffer = 110/100).
 */
export const SLOWSTAKE_FEE_BUFFER = {
  /** Fee buffer percentage (120% = 20% buffer) */
  PERCENTAGE: 120n,
  /** Divisor for percentage calculation */
  DIVISOR: 100n,
} as const;

/**
 * Gas Estimation Constants
 */

/**
 * Fast stake gas estimation parameters based on real transaction data.
 * Values derived from actual Base network transactions for accurate estimates.
 */
export const FAST_STAKE_GAS_ESTIMATION = {
  /**
   * Typical gas used for fast stake transactions.
   * Based on real data: wrapped ~133k, native ~147k gas.
   */
  ESTIMATED_GAS_USED: 150000n,

  /**
   * Conservative gas price estimate in wei.
   * Based on real Base network data showing ~2.5M wei actual prices.
   * Using 5M wei as buffer for network congestion.
   */
  ESTIMATED_GAS_PRICE: 5000000n, // ~5M wei (0.005 Gwei)
} as const;

/**
 * CCIP Protocol Constants
 */

/**
 * CCIP EVMExtraArgsV1 version identifier.
 * Used for encoding gas limits in CCIP messages.
 */
export const CCIP_EXTRA_ARGS_V1_VERSION = '0x97a657c9';

/**
 * Placeholder recipient address used for fee estimation.
 * A dummy address that matches the expected format for accurate fee calculation.
 */
export const CCIP_FEE_ESTIMATION_PLACEHOLDER_RECIPIENT =
  '0x0000000000000000000000000000000000000001';
