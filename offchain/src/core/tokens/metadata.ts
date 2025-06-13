import { formatUnits } from 'ethers';
import type { JsonRpcProvider } from 'ethers';
import type { Address } from '@/types';
import { IERC20__factory } from '@/generated/typechain';
import type { TokenInfo, TokenBalance } from './interfaces';

/**
 * Fetch metadata for a single token.
 *
 * @param tokenAddress - Token contract address
 * @param provider - JSON-RPC provider
 * @returns Token metadata including name, symbol, and decimals
 */
export async function fetchTokenMetadata(
  tokenAddress: Address,
  provider: JsonRpcProvider
): Promise<TokenInfo> {
  const token = IERC20__factory.connect(tokenAddress, provider);

  const [name, symbol, decimals] = await Promise.all([
    token.name(),
    token.symbol(),
    token.decimals(),
  ]);

  return {
    address: tokenAddress,
    name,
    symbol,
    decimals: Number(decimals),
  };
}

/**
 * Fetch metadata for multiple tokens in parallel.
 * More efficient than calling fetchTokenMetadata multiple times.
 *
 * @param tokenAddresses - Array of token contract addresses
 * @param provider - JSON-RPC provider
 * @returns Array of token metadata in the same order as input
 */
export async function fetchTokensMetadata(
  tokenAddresses: Address[],
  provider: JsonRpcProvider
): Promise<TokenInfo[]> {
  const metadataPromises = tokenAddresses.map(address =>
    fetchTokenMetadata(address, provider)
  );

  return Promise.all(metadataPromises);
}

/**
 * Fetch token balance for a specific holder.
 *
 * @param tokenAddress - Token contract address
 * @param holderAddress - Address to check balance for
 * @param provider - JSON-RPC provider
 * @returns Raw balance in token's smallest unit
 */
export async function fetchTokenBalance(
  tokenAddress: Address,
  holderAddress: Address,
  provider: JsonRpcProvider
): Promise<bigint> {
  const token = IERC20__factory.connect(tokenAddress, provider);
  return token.balanceOf(holderAddress);
}

/**
 * Fetch complete token information including balance.
 * Combines metadata and balance fetching for convenience.
 *
 * @param tokenAddress - Token contract address
 * @param holderAddress - Address to check balance for
 * @param provider - JSON-RPC provider
 * @returns Complete token information with balance
 */
export async function fetchTokenWithBalance(
  tokenAddress: Address,
  holderAddress: Address,
  provider: JsonRpcProvider
): Promise<TokenBalance> {
  const token = IERC20__factory.connect(tokenAddress, provider);

  const [name, symbol, decimals, balance] = await Promise.all([
    token.name(),
    token.symbol(),
    token.decimals(),
    token.balanceOf(holderAddress),
  ]);

  const tokenDecimals = Number(decimals);
  const formattedBalance = formatUnits(balance, tokenDecimals);

  return {
    address: tokenAddress,
    name,
    symbol,
    decimals: tokenDecimals,
    balance,
    formattedBalance,
  };
}

/**
 * Fetch multiple tokens with balances in parallel.
 * Efficient way to get complete information for multiple tokens.
 *
 * @param tokenAddresses - Array of token contract addresses
 * @param holderAddress - Address to check balances for
 * @param provider - JSON-RPC provider
 * @returns Array of complete token information with balances
 */
export async function fetchTokensWithBalances(
  tokenAddresses: Address[],
  holderAddress: Address,
  provider: JsonRpcProvider
): Promise<TokenBalance[]> {
  const balancePromises = tokenAddresses.map(address =>
    fetchTokenWithBalance(address, holderAddress, provider)
  );

  return Promise.all(balancePromises);
}

/**
 * Calculate balance ratio between two tokens (normalized for different decimals).
 * Useful for pool composition analysis.
 *
 * @param tokenA - First token balance
 * @param tokenB - Second token balance
 * @param precision - Number of decimal places for the ratio (default: 3)
 * @returns Formatted ratio as string (tokenB / tokenA)
 */
export function calculateBalanceRatio(
  tokenA: TokenBalance,
  tokenB: TokenBalance,
  precision: number = 3
): string {
  if (tokenA.balance === 0n) {
    return '0';
  }

  // Normalize both balances to 18 decimals for fair comparison
  const normalizedTokenA =
    tokenA.balance * 10n ** (18n - BigInt(tokenA.decimals));
  const normalizedTokenB =
    tokenB.balance * 10n ** (18n - BigInt(tokenB.decimals));

  // Calculate ratio with specified precision
  const precisionMultiplier = 10n ** BigInt(precision + 3); // +3 for extra precision in calculation
  const ratio = (normalizedTokenB * precisionMultiplier) / normalizedTokenA;

  return (Number(ratio) / Number(10n ** BigInt(precision + 3))).toFixed(
    precision
  );
}
