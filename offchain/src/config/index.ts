/**
 * Central configuration exports for the Chainlink CSR Liquid Staking Framework.
 *
 * This index provides a clean, centralized interface to all configuration modules,
 * ensuring consistent imports across the application and improving developer experience.
 */

// Core configuration modules
export * from './ccip';
export * from './constants';
export * from './networks';
export * from './protocols';
export * from './types';
export * from './wallet';

// Re-export commonly used functions with clear naming
export {
  // Environment and Network utilities (consolidated)
  ENV,
  getEnvironmentInfo,
  getRpcUrlFromEnv,
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
  getProtocolAddress,
  LIDO_PROTOCOL,
  SUPPORTED_PROTOCOLS,
} from './protocols';

// Wallet utilities
export { createWallet, createProvider, isValidPrivateKey } from './wallet';

// Type utilities
export { isValidPaymentMethod, isValidCCIPFeePaymentMethod } from './types';

// Configuration constants
export {
  ETHEREUM_MAINNET,
  OPTIMISM_MAINNET,
  ARBITRUM_ONE,
  BASE_MAINNET,
} from './networks';

// Application constants
export {
  NUMBER_BLOCKS_TO_WAIT,
  DEFAULT_SLIPPAGE_TOLERANCE,
  TESTING_AMOUNTS,
  // SlowStake constants
  SLOWSTAKE_GAS_LIMIT_MULTIPLIER,
  SLOWSTAKE_FEE_BUFFER,
  // Gas estimation constants
  FAST_STAKE_GAS_ESTIMATION,
  // CCIP constants
  CCIP_EXTRA_ARGS_V1_VERSION,
  CCIP_FEE_ESTIMATION_PLACEHOLDER_RECIPIENT,
} from './constants';
