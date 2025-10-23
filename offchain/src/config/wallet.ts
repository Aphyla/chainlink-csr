import { JsonRpcProvider, Wallet } from 'ethers';
import type { SupportedChainId } from '@/types';
import { getNetworkConfig, ENV } from './networks';

/**
 * Create a wallet instance for a specific chain using private key from environment.
 *
 * @param chainKey - The canonical chain key to connect to
 * @param privateKey - Optional private key override. If not provided, reads from PRIVATE_KEY env var
 * @returns Configured wallet instance connected to the specified chain
 *
 * @throws Error if private key is not provided or invalid
 */
export function createWallet(
  chainKey: SupportedChainId,
  privateKey?: string
): Wallet {
  const key = privateKey || ENV.privateKey;

  if (!key) {
    throw new Error(
      'Private key is required. Set PRIVATE_KEY environment variable or pass as parameter.'
    );
  }

  const config = getNetworkConfig(chainKey);
  const provider = new JsonRpcProvider(config.rpcUrl);

  return new Wallet(key, provider);
}

/**
 * Create a read-only provider for a specific chain.
 *
 * @param chainKey - The canonical chain key to connect to
 * @returns JsonRpcProvider instance for the specified chain
 */
export function createProvider(chainKey: SupportedChainId): JsonRpcProvider {
  const config = getNetworkConfig(chainKey);
  return new JsonRpcProvider(config.rpcUrl);
}

/**
 * Validate that a private key is properly formatted.
 *
 * @param privateKey - The private key to validate
 * @returns true if valid, false otherwise
 */
export function isValidPrivateKey(privateKey: string): boolean {
  try {
    new Wallet(privateKey);
    return true;
  } catch {
    return false;
  }
}
