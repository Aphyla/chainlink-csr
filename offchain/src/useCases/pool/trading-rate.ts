import { formatUnits } from 'ethers';
import type { Address, SupportedChainId } from '@/types';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import {
  fetchOracleData,
  calculateEffectivePrice,
  formatFeePercentage,
} from '@/core/oracle/pricing';
import { fetchTokensMetadata } from '@/core/tokens/metadata';
import type { TokenInfo } from '@/core/tokens/interfaces';
import type { ProtocolConfig } from '@/core/protocols/interfaces';

/**
 * Parameters accepted by {@link getTradingRate}.
 */
export interface TradingRateParams {
  /** Supported chain key for operations. */
  readonly chainKey: SupportedChainId;
  /** Protocol configuration to use. */
  readonly protocol: ProtocolConfig;
}

/**
 * Oracle pricing information.
 */
export interface OraclePricing {
  /** Current oracle price (TOKEN_OUT per TOKEN_IN, scaled by 1e18) */
  readonly price: bigint;
  /** Formatted oracle price */
  readonly formattedPrice: string;
  /** Oracle heartbeat in seconds (how often it updates) */
  readonly heartbeat: bigint;
  /** Whether the oracle price is inverted */
  readonly inverted: boolean;
  /** Oracle output decimals (should be 18 for PriceOracle) */
  readonly decimals: number;
}

/**
 * Fee information for the pool.
 */
export interface FeeInfo {
  /** Fee rate (scaled by 1e18) */
  readonly rate: bigint;
  /** Fee percentage (human readable) */
  readonly percentage: string;
}

// TokenInfo is now imported from @/core/tokens/interfaces

/**
 * Effective exchange rate after fees.
 */
export interface EffectiveRate {
  /** Raw exchange rate (before fees) */
  readonly oracleRate: string;
  /** Effective rate after fees */
  readonly effectiveRate: string;
  /** Rate description */
  readonly description: string;
}

/**
 * Result returned by {@link getTradingRate}.
 */
export interface TradingRateResult {
  /** OraclePool contract address */
  readonly poolAddress: Address;
  /** CustomSender contract address */
  readonly senderAddress: Address;
  /** PriceOracle contract address */
  readonly oracleAddress: Address;
  /** TOKEN_IN information */
  readonly tokenIn: TokenInfo;
  /** TOKEN_OUT information */
  readonly tokenOut: TokenInfo;
  /** Oracle pricing details */
  readonly oracle: OraclePricing;
  /** Pool fee information */
  readonly fee: FeeInfo;
  /** Effective exchange rates */
  readonly rate: EffectiveRate;
}

// formatHeartbeat is now imported from @/core/oracle/pricing

/**
 * Protocol-agnostic function to get current trading rates for fast staking.
 *
 * This function retrieves:
 * - Oracle price (current market rate)
 * - Pool fees
 * - Effective exchange rate users would receive
 *
 * Use this to show users the actual rate they'll get for fast staking,
 * not just the pool composition ratios.
 */
export async function getTradingRate(
  params: TradingRateParams
): Promise<TradingRateResult> {
  const { chainKey, protocol } = params;

  // 1. Setup all contracts using the protocol-agnostic utility
  const setup = await setupLiquidStakingContracts({ chainKey, protocol });
  const { addresses, contracts, provider } = setup;

  // 2. Fetch oracle data, fee rate, and token metadata in parallel
  const [oracleData, feeRate, tokensMetadata] = await Promise.all([
    fetchOracleData(addresses.priceOracle, provider),
    contracts.oraclePool.getFee(),
    fetchTokensMetadata([addresses.tokenIn, addresses.tokenOut], provider),
  ]);

  // Safe destructuring - we know there are exactly 2 tokens
  const [tokenInInfo, tokenOutInfo] = tokensMetadata as [TokenInfo, TokenInfo];

  // 3. Calculate rates using core utilities
  const oracleRateFormatted = formatUnits(
    oracleData.price,
    oracleData.decimals
  );
  const effectivePrice = calculateEffectivePrice(oracleData.price, feeRate);
  const effectiveRateFormatted = formatUnits(
    effectivePrice,
    oracleData.decimals
  );
  const feePercentage = formatFeePercentage(feeRate);

  return {
    poolAddress: addresses.oraclePool,
    senderAddress: addresses.customSender,
    oracleAddress: addresses.priceOracle,
    tokenIn: tokenInInfo,
    tokenOut: tokenOutInfo,
    oracle: {
      price: oracleData.price,
      formattedPrice: oracleRateFormatted,
      heartbeat: oracleData.heartbeat,
      inverted: oracleData.isInverse,
      decimals: oracleData.decimals,
    },
    fee: {
      rate: feeRate,
      percentage: feePercentage,
    },
    rate: {
      oracleRate: `1 ${tokenInInfo.symbol} = ${oracleRateFormatted} ${tokenOutInfo.symbol}`,
      effectiveRate: `1 ${tokenInInfo.symbol} = ${effectiveRateFormatted} ${tokenOutInfo.symbol}`,
      description: `After ${feePercentage} fee`,
    },
  };
}
