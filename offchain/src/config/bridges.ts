// offchain/src/config/bridges.ts
// Centralised bridge-fee defaults for Destination → Origin transfers
// Source of truth for hard-coded parameters originally set in integration tests.
// Numbers were taken from test/integration/CCIPIntegrationLIDO.t.sol at the
// respective fork blocks. Update here if bridge pricing changes.

import { parseEther, parseUnits } from 'ethers';

/** Arbitrum bridge parameters */
export interface ArbitrumBridgeDefaults {
  readonly maxSubmissionCost: bigint; // wei
  readonly maxGas: number;
  readonly gasPriceBid: bigint; // wei (gas price)
}

/** Optimism/Base bridge parameters */
export interface OptimismBridgeDefaults {
  readonly l2Gas: number;
  readonly feeAmount?: bigint; // Always 0 for canonical bridge (kept for completeness)
}

/** Default parameters per bridge type */
export const DEFAULT_BRIDGE_PARAMS = {
  arbitrum: {
    // 0.01 ETH max submission cost
    maxSubmissionCost: parseEther('0.01'),
    maxGas: 100_000,
    // 45 gwei gas bid
    gasPriceBid: parseUnits('45', 'gwei'),
  } satisfies ArbitrumBridgeDefaults,
  optimism: {
    l2Gas: 100_000,
    feeAmount: 0n, // Canonical bridge is currently free
  } satisfies OptimismBridgeDefaults,
  base: {
    l2Gas: 100_000,
    feeAmount: 0n, // Canonical bridge is currently free
  } satisfies OptimismBridgeDefaults,
} as const;
