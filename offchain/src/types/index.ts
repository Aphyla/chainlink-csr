/**
 * Ethereum address type - 42 character hex string starting with 0x.
 */
export type Address = string;

/**
 * Supported chain IDs for Lido CSR operations.
 */
export type SupportedChainId =
  | 'ETHEREUM_MAINNET'
  | 'OPTIMISM_MAINNET'
  | 'ARBITRUM_ONE'
  | 'BASE_MAINNET';

/**
 * Chain configuration for network settings.
 */
export interface ChainConfig {
  readonly chainId: number;
  readonly name: string;
  readonly rpcUrl: string;
  readonly explorer: string;
}
