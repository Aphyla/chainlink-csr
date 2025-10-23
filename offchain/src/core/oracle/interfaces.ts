import type { JsonRpcProvider } from 'ethers';
import type { Address } from '@/types';

/**
 * Oracle pricing data from a price oracle contract.
 */
export interface OracleData {
  /** Current oracle price (scaled by oracle decimals) */
  readonly price: bigint;
  /** Whether the oracle price is inverted */
  readonly isInverse: boolean;
  /** Oracle heartbeat in seconds (max staleness) */
  readonly heartbeat: bigint;
  /** Oracle output decimals (usually 18) */
  readonly decimals: number;
  /** Oracle contract address */
  readonly address: Address;
}

/**
 * Formatted oracle data for display purposes.
 */
export interface FormattedOracleData extends OracleData {
  /** Human-readable formatted price */
  readonly formattedPrice: string;
  /** Formatted heartbeat duration */
  readonly formattedHeartbeat: string;
}

/**
 * Oracle parameters for data fetching.
 */
export interface OracleParams {
  /** Oracle contract address */
  readonly oracleAddress: Address;
  /** Optional custom provider */
  readonly provider?: JsonRpcProvider;
}
