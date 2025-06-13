import type { JsonRpcProvider } from 'ethers';
import type { Address } from '@/types';
import type {
  CustomSenderReferral,
  OraclePool,
  PriceOracle,
  IERC20,
} from '@/generated/typechain';

/**
 * Contract addresses for a liquid staking protocol setup.
 * Contains all the contract addresses needed for operations.
 */
export interface ContractAddresses {
  /** CustomSenderReferral contract address */
  readonly customSender: Address;
  /** OraclePool contract address */
  readonly oraclePool: Address;
  /** PriceOracle contract address */
  readonly priceOracle: Address;
  /** Input token address (usually WETH) */
  readonly tokenIn: Address;
  /** Output token address (usually liquid staking token like wstETH) */
  readonly tokenOut: Address;
  /** Wrapped native token address (WETH, WMATIC, etc.) */
  readonly wnative: Address;
  /** LINK token address */
  readonly linkToken: Address;
}

/**
 * Connected contract instances for a liquid staking protocol.
 * All contracts are connected to the appropriate provider and ready for calls.
 */
export interface ContractInstances {
  /** CustomSenderReferral contract instance */
  readonly customSender: CustomSenderReferral;
  /** OraclePool contract instance */
  readonly oraclePool: OraclePool;
  /** PriceOracle contract instance */
  readonly priceOracle: PriceOracle;
  /** Input token contract instance */
  readonly tokenIn: IERC20;
  /** Output token contract instance */
  readonly tokenOut: IERC20;
}

/**
 * Complete contract setup result for a liquid staking protocol.
 * Contains everything needed to interact with the protocol.
 */
export interface ContractSetupResult {
  /** JSON-RPC provider for blockchain interactions */
  readonly provider: JsonRpcProvider;
  /** All contract addresses */
  readonly addresses: ContractAddresses;
  /** All connected contract instances */
  readonly contracts: ContractInstances;
  /** Protocol name for reference */
  readonly protocolName: string;
  /** Chain key for reference */
  readonly chainKey: string;
}

/**
 * Basic contract connection parameters.
 */
export interface ContractConnectionParams {
  /** Chain to connect to */
  readonly chainKey: string;
  /** Contract address to connect to */
  readonly contractAddress: Address;
  /** Optional custom provider (if not provided, will create one) */
  readonly provider?: JsonRpcProvider;
}
