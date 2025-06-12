/**
 * Centralized environment configuration for the Chainlink CSR Framework.
 *
 * This module consolidates all environment variable handling,
 * providing type-safe access and clear documentation of required variables.
 */

import 'dotenv/config';

/**
 * Environment configuration interface defining all supported environment variables.
 */
export interface EnvironmentConfig {
  // Wallet configuration
  readonly privateKey?: string;

  // RPC URLs (optional - fallback to public RPCs)
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
 * Get environment info for debugging and logging.
 */
export function getEnvironmentInfo(): {
  hasPrivateKey: boolean;
  customRpcUrls: string[];
} {
  return {
    hasPrivateKey: Boolean(ENV.privateKey),
    customRpcUrls: [
      ENV.optimismRpcUrl && 'Optimism',
      ENV.arbitrumRpcUrl && 'Arbitrum',
      ENV.baseRpcUrl && 'Base',
    ].filter(Boolean) as string[],
  };
}
