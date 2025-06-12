import { formatUnits } from 'ethers';
import type { Address, SupportedChainId } from '@/types';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import { formatFeePercentage } from '@/core/oracle/pricing';
import { fetchTokenBalance } from '@/core/tokens/metadata';
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
  /** Current oracle price (TOKEN_IN per TOKEN_OUT, scaled by 1e18) */
  readonly price: bigint;
  /** Formatted oracle price */
  readonly formattedPrice: string;
  /** Oracle heartbeat in seconds (how often it updates) */
  readonly heartbeat: bigint;
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
  /** Oracle rate showing cost (1 TOKEN_OUT = X TOKEN_IN) */
  readonly oracleRate: string;
  /** Effective rate showing what you receive (1 TOKEN_IN = X TOKEN_OUT) */
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

/**
 * Protocol-agnostic function to get current trading rates for fast staking.
 *
 * This function retrieves:
 * - Oracle price (current market rate)
 * - Pool fees
 * - Effective exchange rate users would receive (calculated using actual transaction math)
 *
 * Optimized to minimize RPC calls by fetching only essential data
 * and breaking calls into smaller batches to avoid provider limits.
 */
export async function getTradingRate(
  params: TradingRateParams
): Promise<TradingRateResult> {
  const { chainKey, protocol } = params;

  // 1. Setup all contracts using the protocol-agnostic utility
  const setup = await setupLiquidStakingContracts({ chainKey, protocol });
  const { addresses, contracts, provider } = setup;

  // 2. Fetch only essential data in smaller batches to avoid RPC limits
  // Batch 1: Oracle data (3 calls)
  const [oraclePrice, oracleHeartbeat, oracleDecimals] = await Promise.all([
    contracts.priceOracle.getLatestAnswer(),
    contracts.priceOracle.HEARTBEAT(),
    contracts.priceOracle.DECIMALS(),
  ]);

  // Batch 2: Pool data (3 calls)
  const [feeRate, tokenInDecimals, tokenOutDecimals] = await Promise.all([
    contracts.oraclePool.getFee(),
    contracts.tokenIn.decimals(),
    contracts.tokenOut.decimals(),
  ]);

  // Batch 3: Token symbols and pool balance (3 calls)
  const [tokenInSymbol, tokenOutSymbol, availableOut] = await Promise.all([
    contracts.tokenIn.symbol(),
    contracts.tokenOut.symbol(),
    fetchTokenBalance(addresses.tokenOut, addresses.oraclePool, provider),
  ]);

  // 3. Calculate ACTUAL effective rate using the same math as OraclePool.swap
  const oneTokenIn = 10n ** 18n; // 1 TOKEN_IN
  const PRECISION = 10n ** 18n;

  // Contract math: feeAmount = amountIn * fee / 1e18
  const feeAmount = (oneTokenIn * feeRate) / PRECISION;
  const amountAfterFee = oneTokenIn - feeAmount;

  // Contract math: amountOut = (amountIn - feeAmount) * 1e18 / price
  const amountOut = (amountAfterFee * PRECISION) / oraclePrice;

  // Check liquidity sufficiency
  const hasSufficientLiquidity = amountOut <= availableOut;

  // 4. Format rates using core utilities
  const oracleRateFormatted = formatUnits(oraclePrice, Number(oracleDecimals));
  const effectiveRateFormatted = formatUnits(
    amountOut,
    Number(tokenOutDecimals)
  );
  const feePercentage = formatFeePercentage(feeRate);

  return {
    poolAddress: addresses.oraclePool,
    senderAddress: addresses.customSender,
    oracleAddress: addresses.priceOracle,
    tokenIn: {
      address: addresses.tokenIn,
      symbol: tokenInSymbol,
      name: tokenInSymbol, // Use symbol as name to avoid extra call
      decimals: Number(tokenInDecimals),
    },
    tokenOut: {
      address: addresses.tokenOut,
      symbol: tokenOutSymbol,
      name: tokenOutSymbol, // Use symbol as name to avoid extra call
      decimals: Number(tokenOutDecimals),
    },
    oracle: {
      price: oraclePrice,
      formattedPrice: oracleRateFormatted,
      heartbeat: oracleHeartbeat,
      decimals: Number(oracleDecimals),
    },
    fee: {
      rate: feeRate,
      percentage: feePercentage,
    },
    rate: {
      oracleRate: `1 ${tokenOutSymbol} = ${oracleRateFormatted} ${tokenInSymbol}`,
      effectiveRate: `1 ${tokenInSymbol} = ${effectiveRateFormatted} ${tokenOutSymbol}`,
      description: `After ${feePercentage} fee${hasSufficientLiquidity ? '' : ' (⚠️ Low liquidity)'}`,
    },
  };
}
