/**
 * Protocol Configuration for Chainlink CSR Framework.
 *
 * Consolidates protocol definitions, addresses, and related utilities
 * to provide a single source of truth for all protocol configurations.
 */

import type { Address, SupportedChainId } from '@/types';
import type {
  ProtocolConfig,
  ProtocolRegistry,
} from '@/core/protocols/interfaces';
import { ZeroAddress } from 'ethers';

/**
 * Protocol Addresses
 */

/**
 * Lido Protocol CustomSender contract addresses per chain.
 */
export const LIDO_CUSTOM_SENDER: Record<SupportedChainId, Address> = {
  // Ethereum mainnet
  ETHEREUM_MAINNET: ZeroAddress,
  // Optimism mainnet
  OPTIMISM_MAINNET: '0x328de900860816d29D1367F6903a24D8ed40C997',
  // Arbitrum One
  ARBITRUM_ONE: '0x72229141D4B016682d3618ECe47c046f30Da4AD1',
  // Base mainnet
  BASE_MAINNET: '0x328de900860816d29D1367F6903a24D8ed40C997',
} as const;

/**
 * Protocol Configurations
 */

/**
 * Lido Protocol Configuration
 * Reference implementation for liquid staking protocol configuration.
 */
export const LIDO_PROTOCOL: ProtocolConfig = {
  name: 'lido',
  description:
    'Liquid staking for Ethereum - stake ETH and receive stETH while keeping your ETH liquid',
  customSenderAddresses: LIDO_CUSTOM_SENDER,
} as const;

/**
 * Registry of all supported liquid staking protocols.
 *
 * To add a new protocol:
 * 1. Add protocol addresses above in this file
 * 2. Create protocol configuration following the `ProtocolConfig` interface
 * 3. Add it to this registry
 *
 * Example for future protocols:
 * ```typescript
 * export const ROCKET_POOL_PROTOCOL: ProtocolConfig = {
 *   name: 'rocket-pool',
 *   description: 'Decentralized liquid staking for Ethereum',
 *   customSenderAddresses: ROCKET_POOL_CUSTOM_SENDER,
 * };
 * ```
 */
export const SUPPORTED_PROTOCOLS: ProtocolRegistry = {
  LIDO: LIDO_PROTOCOL,
} as const;

/**
 * Protocol Utilities
 */

/**
 * Get protocol configuration by name.
 * Useful for dynamic protocol selection.
 *
 * @param protocolName - The protocol name (e.g., 'lido', 'rocket-pool')
 * @returns Protocol configuration or undefined if not found
 */
export function getProtocol(protocolName: string): ProtocolConfig | undefined {
  return Object.values(SUPPORTED_PROTOCOLS).find(
    protocol => protocol.name === protocolName
  );
}

/**
 * Get all available protocol names.
 * Useful for UI dropdowns or CLI options.
 */
export function getAvailableProtocols(): string[] {
  return Object.values(SUPPORTED_PROTOCOLS).map(protocol => protocol.name);
}

/**
 * Validate if a protocol is supported on a specific chain.
 * Checks both that the chain key exists AND that it has a valid non-zero address.
 */
export function isProtocolSupportedOnChain(
  protocol: ProtocolConfig,
  chainKey: SupportedChainId
): boolean {
  const address =
    protocol.customSenderAddresses[
      chainKey as keyof typeof protocol.customSenderAddresses
    ];
  return address !== undefined && address !== ZeroAddress;
}

/**
 * Get protocol addresses for a specific protocol and chain.
 * Provides type-safe access to protocol contract addresses.
 */
export function getProtocolAddress(
  protocolName: string,
  chainKey: SupportedChainId
): Address | undefined {
  const protocol = getProtocol(protocolName);
  return protocol?.customSenderAddresses[chainKey];
}
