import type { SupportedChainId } from '@/types';

/**
 * CCIP Chain selectors for supported networks
 * These are used for cross-chain messaging via Chainlink CCIP
 */
export const CCIP_CHAIN_SELECTORS: Record<SupportedChainId, string> = {
  ETHEREUM_MAINNET: '5009297550715157269',
  ARBITRUM_ONE: '4949039107694359620',
  OPTIMISM_MAINNET: '3734403246176062136',
  BASE_MAINNET: '15971525489660198786',
} as const;

/**
 * Bridge types for each supported chain
 */
export type BridgeType = 'native' | 'arbitrum' | 'optimism' | 'base';

/**
 * Bridge configurations for return path (Ethereum → L2)
 */
export const BRIDGE_CONFIGS: Record<
  SupportedChainId,
  {
    type: BridgeType;
    defaultGasLimit?: number;
    supportedReturnPath: boolean;
  }
> = {
  ETHEREUM_MAINNET: {
    type: 'native',
    supportedReturnPath: false, // No return path from Ethereum
  },
  ARBITRUM_ONE: {
    type: 'arbitrum',
    defaultGasLimit: 100_000,
    supportedReturnPath: true,
  },
  OPTIMISM_MAINNET: {
    type: 'optimism',
    defaultGasLimit: 100_000,
    supportedReturnPath: true,
  },
  BASE_MAINNET: {
    type: 'base',
    defaultGasLimit: 100_000,
    supportedReturnPath: true,
  },
} as const;

/**
 * Get CCIP chain selector for a given chain
 */
export function getCCIPChainSelector(chainKey: SupportedChainId): string {
  return CCIP_CHAIN_SELECTORS[chainKey];
}

/**
 * Get bridge configuration for a given chain
 */
export function getBridgeConfig(chainKey: SupportedChainId): {
  type: BridgeType;
  defaultGasLimit?: number;
  supportedReturnPath: boolean;
} {
  return BRIDGE_CONFIGS[chainKey];
}
