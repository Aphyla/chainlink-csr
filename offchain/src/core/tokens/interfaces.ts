import type { Address } from '@/types';

/**
 * Basic token metadata information.
 * This is the unified interface for token information across the framework.
 */
export interface TokenInfo {
  /** Token contract address */
  readonly address: Address;
  /** Token name (e.g., "Wrapped Ether") */
  readonly name: string;
  /** Token symbol (e.g., "WETH") */
  readonly symbol: string;
  /** Token decimals (e.g., 18) */
  readonly decimals: number;
}

/**
 * Token information with balance data.
 * Extends TokenInfo to include balance and formatted balance.
 */
export interface TokenBalance extends TokenInfo {
  /** Raw balance in token's smallest unit (wei) */
  readonly balance: bigint;
  /** Human-readable formatted balance */
  readonly formattedBalance: string;
}

/**
 * Token pair information for trading operations.
 * Represents the input and output tokens for liquid staking.
 */
export interface TokenPair {
  /** Input token (usually WETH) */
  readonly tokenIn: TokenInfo;
  /** Output token (usually liquid staking token like wstETH) */
  readonly tokenOut: TokenInfo;
}

/**
 * Token pair with balance information.
 * Useful for pool balance queries and liquidity analysis.
 */
export interface TokenPairWithBalances {
  /** Input token with balance */
  readonly tokenIn: TokenBalance;
  /** Output token with balance */
  readonly tokenOut: TokenBalance;
  /** Balance ratio for analysis (tokenOut.balance / tokenIn.balance) */
  readonly balanceRatio: string;
}
