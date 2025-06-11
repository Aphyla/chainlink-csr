import type { Address, SupportedChainId } from '@/types';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import {
  fetchTokensWithBalances,
  calculateBalanceRatio,
} from '@/core/tokens/metadata';
import type { TokenBalance } from '@/core/tokens/interfaces';
import type { ProtocolConfig } from '@/core/protocols/interfaces';

/**
 * Parameters accepted by {@link getPoolBalances}.
 */
export interface PoolBalanceParams {
  /** Supported chain key for operations. */
  readonly chainKey: SupportedChainId;
  /** Protocol configuration to use. */
  readonly protocol: ProtocolConfig;
}

// TokenBalance is now imported from @/core/tokens/interfaces

/**
 * Result returned by {@link getPoolBalances}.
 */
export interface PoolBalanceResult {
  /** OraclePool contract address */
  readonly poolAddress: Address;
  /** CustomSender contract address */
  readonly senderAddress: Address;
  /** TOKEN_IN balance and metadata (usually WETH) */
  readonly tokenIn: TokenBalance;
  /** TOKEN_OUT balance and metadata (usually wstETH) */
  readonly tokenOut: TokenBalance;
  /** Total value ratio: tokenOut.balance / tokenIn.balance */
  readonly balanceRatio: string;
}

// Using ethers.js formatUnits for consistent, battle-tested formatting

/**
 * Protocol-agnostic query for pool balances (TOKEN_IN and TOKEN_OUT).
 *
 * This function retrieves the current balances of both tokens in the pool,
 * along with complete token metadata (name, symbol, decimals).
 * Useful for checking pool liquidity without performing a full estimation.
 */
export async function getPoolBalances(
  params: PoolBalanceParams
): Promise<PoolBalanceResult> {
  const { chainKey, protocol } = params;

  // 1. Setup all contracts using the protocol-agnostic utility
  const setup = await setupLiquidStakingContracts({ chainKey, protocol });
  const { addresses, provider } = setup;

  // 2. Fetch token balances and metadata in parallel using core utility
  const tokensWithBalances = await fetchTokensWithBalances(
    [addresses.tokenIn, addresses.tokenOut],
    addresses.oraclePool,
    provider
  );

  // Safe destructuring - we know there are exactly 2 tokens
  const [tokenInInfo, tokenOutInfo] = tokensWithBalances as [
    TokenBalance,
    TokenBalance,
  ];

  // 3. Calculate balance ratio using core utility
  const balanceRatio = calculateBalanceRatio(tokenInInfo, tokenOutInfo);

  return {
    poolAddress: addresses.oraclePool,
    senderAddress: addresses.customSender,
    tokenIn: tokenInInfo,
    tokenOut: tokenOutInfo,
    balanceRatio,
  };
}
