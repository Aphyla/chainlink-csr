import type { Address, SupportedChainId } from '@/types';

/**
 * Configuration for a liquid staking protocol.
 * This interface defines the minimum required configuration
 * for any liquid staking protocol to work with our framework.
 */
export interface ProtocolConfig {
  /** Protocol name (e.g., 'lido', 'rocket-pool') */
  readonly name: string;
  /** Brief protocol description */
  readonly description: string;
  /** Custom Sender contract addresses for each supported chain */
  readonly customSenderAddresses: Record<SupportedChainId, Address>;
}

/**
 * Registry of all supported liquid staking protocols.
 * This allows the framework to work with multiple protocols
 * through simple configuration.
 */
export interface ProtocolRegistry {
  readonly [protocolKey: string]: ProtocolConfig;
}

/**
 * Parameters for protocol selection in framework functions.
 */
export interface ProtocolSelector {
  /** Chain to operate on */
  readonly chainKey: SupportedChainId;
  /** Protocol configuration to use */
  readonly protocol: ProtocolConfig;
}
