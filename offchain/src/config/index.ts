/**
 * Central configuration exports for the Chainlink CSR Liquid Staking Framework.
 *
 * This index provides a clean, centralized interface to all configuration modules,
 * ensuring consistent imports across the application and improving developer experience.
 */

// Core configuration modules
export * from './addresses';
export * from './environment';
export * from './networks';
export * from './protocols';
export * from './transactions';
export * from './wallet';

// Re-export commonly used functions with clear naming
export {
  // Environment utilities
  ENV,
  getEnvironmentInfo,
  getRpcUrlFromEnv,
} from './environment';

// Network utilities
export {
  getNetworkConfig,
  getRpcUrl,
  getChainId,
  isSupportedChainId,
  SUPPORTED_CHAIN_KEYS,
} from './networks';

// Protocol utilities
export {
  getProtocol,
  getAvailableProtocols,
  isProtocolSupportedOnChain,
  LIDO_PROTOCOL,
  SUPPORTED_PROTOCOLS,
} from './protocols';

// Wallet utilities
export { createWallet, createProvider, isValidPrivateKey } from './wallet';

// Configuration constants
export { OPTIMISM_MAINNET, ARBITRUM_ONE, BASE_MAINNET } from './networks';
