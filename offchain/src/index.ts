// Protocol-agnostic use cases
export { estimateFastStake } from '@/useCases/fastStake/estimate';
export { executeFastStakeReferral } from '@/useCases/fastStake/execute';
export { getPoolBalances } from '@/useCases/pool/balance';
export { getTradingRate } from '@/useCases/pool/trading-rate';
export { checkTokenAllowance } from '@/useCases/allowance/check';

// Core infrastructure
export { setupLiquidStakingContracts } from '@/core/contracts/setup';
export {
  fetchTokenMetadata,
  fetchTokensMetadata,
  fetchTokenBalance,
  fetchTokenWithBalance,
  fetchTokensWithBalances,
  calculateBalanceRatio,
} from '@/core/tokens/metadata';
export {
  fetchOracleData,
  fetchFormattedOracleData,
  formatHeartbeat,
  formatFeePercentage,
} from '@/core/oracle/pricing';
export {
  LIDO_PROTOCOL,
  SUPPORTED_PROTOCOLS,
  getProtocol,
  getAvailableProtocols,
  isProtocolSupportedOnChain,
} from '@/config/protocols';

// Configuration and utilities
export { createProvider, createWallet } from '@/config/wallet';
export {
  getNetworkConfig,
  getRpcUrl,
  getChainId,
  isSupportedChainId,
  NETWORKS,
  SUPPORTED_CHAIN_KEYS,
  // Chain key constants
  OPTIMISM_MAINNET,
  ARBITRUM_ONE,
  BASE_MAINNET,
} from '@/config/networks';
export { LIDO_CUSTOM_SENDER } from '@/config/protocols';
export {
  NUMBER_BLOCKS_TO_WAIT,
  DEFAULT_SLIPPAGE_TOLERANCE,
  TESTING_AMOUNTS,
} from '@/config';

// Types
export type { Address, SupportedChainId, ChainConfig } from '@/types';

// Core types
export type {
  ProtocolConfig,
  ProtocolRegistry,
  ProtocolSelector,
} from '@/core/protocols/interfaces';
export type {
  ContractAddresses,
  ContractInstances,
  ContractSetupResult,
  ContractConnectionParams,
} from '@/core/contracts/interfaces';
export type {
  TokenInfo,
  TokenBalance,
  TokenPair,
  TokenPairWithBalances,
} from '@/core/tokens/interfaces';
export type {
  OracleData,
  FormattedOracleData,
  OracleParams,
} from '@/core/oracle/interfaces';

// Use case types
export type {
  EstimateFastStakeParams,
  EstimateFastStakeResult,
  ContractInfo,
  FeeBreakdown,
  PriceInfo,
  PoolInfo,
} from '@/useCases/fastStake/estimate';
export type {
  PoolBalanceParams,
  PoolBalanceResult,
} from '@/useCases/pool/balance';
export type {
  TradingRateParams,
  TradingRateResult,
  OraclePricing,
  FeeInfo,
  EffectiveRate,
} from '@/useCases/pool/trading-rate';
export type {
  CheckTokenAllowanceParams,
  CheckTokenAllowanceResult,
  TokenAllowanceInfo,
} from '@/useCases/allowance/check';
export type {
  ExecuteFastStakeReferralParams,
  ExecuteFastStakeReferralResult,
  AllowanceInfo,
  TransactionInfo,
  ReferralEventInfo,
} from '@/useCases/fastStake/execute';

// Centralized types
export type {
  PaymentMethod,
  CCIPFeePaymentMethod,
  SlippageTolerance,
} from '@/config';
