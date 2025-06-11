import type { ChainConfig, SupportedChainId } from '@/types';
import { getRpcUrlFromEnv } from './environment';

// Export chain key constants for type-safe usage
export const OPTIMISM_MAINNET = 'OPTIMISM_MAINNET' as const;
export const ARBITRUM_ONE = 'ARBITRUM_ONE' as const;
export const BASE_MAINNET = 'BASE_MAINNET' as const;

// Array of all supported chain keys (useful for iteration)
export const SUPPORTED_CHAIN_KEYS: readonly SupportedChainId[] = [
  OPTIMISM_MAINNET,
  ARBITRUM_ONE,
  BASE_MAINNET,
] as const;

/**
 * Type guard to check if a string is a valid SupportedChainId.
 */
export function isSupportedChainId(
  chainId: string
): chainId is SupportedChainId {
  return SUPPORTED_CHAIN_KEYS.includes(chainId as SupportedChainId);
}

/**
 * Network configurations for supported chains.
 * RPC URLs can be overridden via environment variables.
 */
export const NETWORKS = {
  [OPTIMISM_MAINNET]: {
    chainId: 10,
    name: 'Optimism',
    rpcUrl: getRpcUrlFromEnv('OPTIMISM_MAINNET'),
    explorer: 'https://optimistic.etherscan.io',
  },
  [ARBITRUM_ONE]: {
    chainId: 42161,
    name: 'Arbitrum One',
    rpcUrl: getRpcUrlFromEnv('ARBITRUM_ONE'),
    explorer: 'https://arbiscan.io',
  },
  [BASE_MAINNET]: {
    chainId: 8453,
    name: 'Base',
    rpcUrl: getRpcUrlFromEnv('BASE_MAINNET'),
    explorer: 'https://basescan.org',
  },
} as const satisfies Record<SupportedChainId, ChainConfig>;

/**
 * Get network configuration by chain key.
 */
export function getNetworkConfig(chainKey: SupportedChainId): ChainConfig {
  const config = NETWORKS[chainKey];
  if (!config) {
    // This should never happen due to TypeScript typing, but keeping for runtime safety
    throw new Error(`Unsupported chainKey: ${chainKey}`);
  }
  return config;
}

/**
 * Get RPC URL for a specific chain, with environment variable override.
 */
export function getRpcUrl(chainKey: SupportedChainId): string {
  return getNetworkConfig(chainKey).rpcUrl;
}

/**
 * Get the numeric chain ID from the chain key.
 */
export function getChainId(chainKey: SupportedChainId): number {
  return getNetworkConfig(chainKey).chainId;
}
