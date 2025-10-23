/**
 * Network and Environment Configuration for Chainlink CSR Framework.
 *
 * Consolidates network definitions, RPC URLs, and environment variable handling
 * for better maintainability and reduced cross-dependencies.
 */

import 'dotenv/config';
import type { ChainConfig, SupportedChainId } from '@/types';

// Export chain key constants for type-safe usage
export const ETHEREUM_MAINNET = 'ETHEREUM_MAINNET' as const;
export const OPTIMISM_MAINNET = 'OPTIMISM_MAINNET' as const;
export const ARBITRUM_ONE = 'ARBITRUM_ONE' as const;
export const BASE_MAINNET = 'BASE_MAINNET' as const;

// Array of all supported chain keys (useful for iteration)
export const SUPPORTED_CHAIN_KEYS: readonly SupportedChainId[] = [
  ETHEREUM_MAINNET,
  OPTIMISM_MAINNET,
  ARBITRUM_ONE,
  BASE_MAINNET,
] as const;

/**
 * Environment configuration interface defining all supported environment variables.
 */
export interface EnvironmentConfig {
  // Wallet configuration
  readonly privateKey?: string;

  // RPC URLs (optional - fallback to public RPCs)
  readonly ethereumRpcUrl?: string;
  readonly optimismRpcUrl?: string;
  readonly arbitrumRpcUrl?: string;
  readonly baseRpcUrl?: string;
}

/**
 * Parse and validate environment variables.
 *
 * @returns Validated environment configuration
 */
function parseEnvironment(): EnvironmentConfig {
  return {
    // Wallet configuration
    ...(process.env.PRIVATE_KEY && { privateKey: process.env.PRIVATE_KEY }),

    // RPC URLs
    ...(process.env.ETHEREUM_RPC_URL && {
      ethereumRpcUrl: process.env.ETHEREUM_RPC_URL,
    }),
    ...(process.env.OPTIMISM_RPC_URL && {
      optimismRpcUrl: process.env.OPTIMISM_RPC_URL,
    }),
    ...(process.env.ARBITRUM_RPC_URL && {
      arbitrumRpcUrl: process.env.ARBITRUM_RPC_URL,
    }),
    ...(process.env.BASE_RPC_URL && { baseRpcUrl: process.env.BASE_RPC_URL }),
  };
}

/**
 * Global environment configuration instance.
 * Parsed once at module load for performance.
 */
export const ENV: EnvironmentConfig = parseEnvironment();

/**
 * Default RPC URLs for each supported chain.
 * Used as fallbacks when environment variables are not set.
 */
export const DEFAULT_RPC_URLS = {
  ETHEREUM_MAINNET: 'https://cloudflare-eth.com',
  OPTIMISM_MAINNET: 'https://mainnet.optimism.io',
  ARBITRUM_ONE: 'https://arb1.arbitrum.io/rpc',
  BASE_MAINNET: 'https://base.llamarpc.com',
} as const;

/**
 * Get RPC URL for a chain with environment variable override support.
 *
 * @param chainKey - The chain to get RPC URL for
 * @returns RPC URL (from env var or default)
 */
export function getRpcUrlFromEnv(
  chainKey: keyof typeof DEFAULT_RPC_URLS
): string {
  switch (chainKey) {
    case 'ETHEREUM_MAINNET':
      return ENV.ethereumRpcUrl || DEFAULT_RPC_URLS.ETHEREUM_MAINNET;
    case 'OPTIMISM_MAINNET':
      return ENV.optimismRpcUrl || DEFAULT_RPC_URLS.OPTIMISM_MAINNET;
    case 'ARBITRUM_ONE':
      return ENV.arbitrumRpcUrl || DEFAULT_RPC_URLS.ARBITRUM_ONE;
    case 'BASE_MAINNET':
      return ENV.baseRpcUrl || DEFAULT_RPC_URLS.BASE_MAINNET;
    default:
      throw new Error(`Unsupported chain: ${chainKey}`);
  }
}

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
  [ETHEREUM_MAINNET]: {
    chainId: 1,
    name: 'Ethereum',
    rpcUrl: getRpcUrlFromEnv('ETHEREUM_MAINNET'),
    explorer: 'https://etherscan.io',
  },
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

/**
 * Get environment info for debugging and logging.
 */
export function getEnvironmentInfo(): {
  hasPrivateKey: boolean;
  customRpcUrls: string[];
} {
  return {
    hasPrivateKey: Boolean(ENV.privateKey),
    customRpcUrls: [
      ENV.ethereumRpcUrl && 'Ethereum',
      ENV.optimismRpcUrl && 'Optimism',
      ENV.arbitrumRpcUrl && 'Arbitrum',
      ENV.baseRpcUrl && 'Base',
    ].filter(Boolean) as string[],
  };
}
