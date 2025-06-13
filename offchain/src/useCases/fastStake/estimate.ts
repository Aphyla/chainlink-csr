import type { Address, SupportedChainId } from '@/types';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import { fetchOracleData } from '@/core/oracle/pricing';
import { fetchTokensMetadata, fetchTokenBalance } from '@/core/tokens/metadata';
import type { TokenInfo } from '@/core/tokens/interfaces';
import type { ProtocolConfig } from '@/core/protocols/interfaces';

/**
 * Parameters accepted by {@link estimateFastStake}.
 */
export interface EstimateFastStakeParams {
  /** Supported chain ID for operations. */
  readonly chainKey: SupportedChainId;
  /** Amount of TOKEN_IN (WETH) provided by the user, in wei. */
  readonly amountIn: bigint;
  /** Protocol configuration to use. */
  readonly protocol: ProtocolConfig;
}

// TokenInfo is now imported from @/core/tokens/interfaces

/**
 * Contract addresses and configuration.
 */
export interface ContractInfo {
  readonly customSender: Address;
  readonly oraclePool: Address;
  readonly priceOracle: Address;
  readonly tokenIn: TokenInfo;
  readonly tokenOut: TokenInfo;
  readonly wnative: Address;
  readonly linkToken: Address;
}

/**
 * Fee breakdown and calculation details.
 */
export interface FeeBreakdown {
  /** Fee percentage (1e18 scale) - e.g., 1e16 = 1% */
  readonly feeRate: bigint;
  /** Absolute fee amount in TOKEN_IN, in wei */
  readonly feeAmount: bigint;
  /** Amount after fee deduction, in wei */
  readonly amountAfterFee: bigint;
}

/**
 * Oracle and pricing information.
 */
export interface PriceInfo {
  /** Current oracle price (1e18 scale) */
  readonly price: bigint;
  /** Price oracle address */
  readonly oracleAddress: Address;
  /** Whether price oracle is inverse (rare case) */
  readonly isInverse: boolean;
  /** Oracle heartbeat (max staleness) */
  readonly heartbeat: bigint;
}

/**
 * Pool liquidity and availability.
 */
export interface PoolInfo {
  /** Available TOKEN_OUT balance in pool */
  readonly availableOut: bigint;
  /** Whether pool has sufficient liquidity for this swap */
  readonly hasSufficientLiquidity: boolean;
  /** Pool sender (CustomSender address) */
  readonly poolSender: Address;
}

/**
 * Result returned by {@link estimateFastStake}.
 */
export interface EstimateFastStakeResult {
  /** Expected LST tokens returned by `fastStake`, in wei. */
  readonly amountOut: bigint;
  /** Detailed fee breakdown */
  readonly fees: FeeBreakdown;
  /** Oracle and pricing details */
  readonly pricing: PriceInfo;
  /** Pool liquidity information */
  readonly pool: PoolInfo;
  /** Contract addresses and token info */
  readonly contracts: ContractInfo;
  /** Effective exchange rate: amountOut / amountIn (1e18 scale) */
  readonly effectiveRate: bigint;
}

const PRECISION = 10n ** 18n;

/**
 * Protocol-agnostic off-chain estimator for `fastStake` operations.
 *
 * It reproduces the on-chain math performed by `OraclePool.swap`:
 *   feeAmount   = amountIn * fee / 1e18
 *   amountOut   = (amountIn - feeAmount) * 1e18 / price
 *
 * Also validates pool liquidity and provides comprehensive breakdown of the operation.
 *
 * Important: this is a *pure* estimation ‑ actual execution may differ if the
 * oracle price or fee changes between the call and the user's transaction.
 */
export async function estimateFastStake(
  params: EstimateFastStakeParams
): Promise<EstimateFastStakeResult> {
  const { chainKey, amountIn, protocol } = params;

  // 1. Setup all contracts using the protocol-agnostic utility
  const setup = await setupLiquidStakingContracts({ chainKey, protocol });
  const { addresses, contracts, provider } = setup;

  // 2. Fetch oracle data and pool configuration in parallel
  const [oracleData, fee, poolSender] = await Promise.all([
    fetchOracleData(addresses.priceOracle, provider),
    contracts.oraclePool.getFee(),
    contracts.oraclePool.SENDER(),
  ]);

  // 3. Fetch token metadata and pool balance in parallel
  const [tokensMetadata, availableOut] = await Promise.all([
    fetchTokensMetadata([addresses.tokenIn, addresses.tokenOut], provider),
    fetchTokenBalance(addresses.tokenOut, addresses.oraclePool, provider),
  ]);

  // Safe destructuring - we know there are exactly 2 tokens
  const [tokenInInfo, tokenOutInfo] = tokensMetadata as [TokenInfo, TokenInfo];

  // 4. Perform same math as OraclePool.swap
  const feeAmount = (amountIn * fee) / PRECISION;
  const amountAfterFee = amountIn - feeAmount;
  const amountOut = (amountAfterFee * PRECISION) / oracleData.price;

  // 5. Calculate effective rate
  const effectiveRate = (amountOut * PRECISION) / amountIn;

  // 6. Check liquidity sufficiency
  const hasSufficientLiquidity = amountOut <= availableOut;

  return {
    amountOut,
    fees: {
      feeRate: fee,
      feeAmount,
      amountAfterFee,
    },
    pricing: {
      price: oracleData.price,
      oracleAddress: addresses.priceOracle,
      isInverse: oracleData.isInverse,
      heartbeat: oracleData.heartbeat,
    },
    pool: {
      availableOut,
      hasSufficientLiquidity,
      poolSender,
    },
    contracts: {
      customSender: addresses.customSender,
      oraclePool: addresses.oraclePool,
      priceOracle: addresses.priceOracle,
      tokenIn: tokenInInfo,
      tokenOut: tokenOutInfo,
      wnative: addresses.wnative,
      linkToken: addresses.linkToken,
    },
    effectiveRate,
  };
}
