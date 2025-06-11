import type {
  ProtocolConfig,
  ProtocolRegistry,
} from '@/core/protocols/interfaces';
import { LIDO_CUSTOM_SENDER } from './addresses';

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
 * 1. Add protocol addresses to `addresses.ts`
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
  // Future protocols will be added here:
  // ROCKET_POOL: ROCKET_POOL_PROTOCOL,
  // FRAX: FRAX_PROTOCOL,
  // STAKEWISE: STAKEWISE_PROTOCOL,
} as const;

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
 */
export function isProtocolSupportedOnChain(
  protocol: ProtocolConfig,
  chainKey: string
): boolean {
  return chainKey in protocol.customSenderAddresses;
}
