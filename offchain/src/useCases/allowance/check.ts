import type { Address, SupportedChainId } from '@/types';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import { fetchTokenMetadata } from '@/core/tokens/metadata';
import type { TokenInfo } from '@/core/tokens/interfaces';
import type { ProtocolConfig } from '@/core/protocols/interfaces';

/**
 * Parameters accepted by {@link checkTokenAllowance}.
 */
export interface CheckTokenAllowanceParams {
  /** Supported chain ID for operations. */
  readonly chainKey: SupportedChainId;
  /** User address to check allowance for. */
  readonly userAddress: Address;
  /** Protocol configuration to use. */
  readonly protocol: ProtocolConfig;
}

/**
 * Token information and allowance details.
 */
export interface TokenAllowanceInfo {
  /** TOKEN contract information */
  readonly token: TokenInfo;
  /** TOKEN address (same as token.address for clarity) */
  readonly tokenAddress: Address;
  /** CustomSender contract address (spender) */
  readonly spenderAddress: Address;
  /** User's current allowance in wei */
  readonly allowance: bigint;
  /** Whether user has unlimited allowance (max uint256) */
  readonly hasUnlimitedAllowance: boolean;
  /** Whether user has any allowance (> 0) */
  readonly hasAllowance: boolean;
  /** User's token balance in wei */
  readonly userBalance: bigint;
}

/**
 * Result returned by {@link checkTokenAllowance}.
 */
export interface CheckTokenAllowanceResult {
  /** Complete allowance information */
  readonly allowanceInfo: TokenAllowanceInfo;
  /** Contract addresses for reference */
  readonly contracts: {
    readonly customSender: Address;
    readonly oraclePool: Address;
    readonly priceOracle: Address;
    readonly wnative: Address;
    readonly linkToken: Address;
  };
  /** Chain and protocol information */
  readonly metadata: {
    readonly chainKey: SupportedChainId;
    readonly protocolName: string;
  };
}

// Maximum uint256 value - indicates unlimited allowance
const MAX_UINT256 = 2n ** 256n - 1n;

/**
 * Protocol-agnostic utility to check TOKEN allowance for a user.
 *
 * This function:
 * 1. Gets the TOKEN address from the CustomSender contract
 * 2. Checks the user's current allowance for TOKEN to the CustomSender
 * 3. Provides detailed allowance status and token information
 * 4. Includes helper flags for common allowance checks
 *
 * The TOKEN address is retrieved from the immutable TOKEN field in CustomSender,
 * which represents the token that users send to perform staking operations
 * (typically WETH on most chains).
 *
 * @param params - Parameters including chain, user address, and protocol
 * @returns Complete allowance information and contract details
 * @throws Error if protocol is not supported on the chain or contracts are misconfigured
 */
export async function checkTokenAllowance(
  params: CheckTokenAllowanceParams
): Promise<CheckTokenAllowanceResult> {
  const { chainKey, userAddress, protocol } = params;

  // 1. Setup all contracts using the protocol-agnostic utility
  const setup = await setupLiquidStakingContracts({ chainKey, protocol });
  const { addresses, contracts, provider } = setup;

  // 2. Get TOKEN address from CustomSender contract
  const tokenAddress = await contracts.customSender.TOKEN();

  // 3. Connect to TOKEN contract and fetch metadata, allowance, and user balance in parallel
  const tokenContract = contracts.tokenIn; // tokenIn is the TOKEN contract
  const [tokenInfo, allowance, userBalance] = await Promise.all([
    fetchTokenMetadata(tokenAddress, provider),
    tokenContract.allowance(userAddress, addresses.customSender),
    tokenContract.balanceOf(userAddress),
  ]);

  // 4. Analyze allowance status
  const hasUnlimitedAllowance = allowance === MAX_UINT256;
  const hasAllowance = allowance > 0n;

  return {
    allowanceInfo: {
      token: tokenInfo,
      tokenAddress,
      spenderAddress: addresses.customSender,
      allowance,
      hasUnlimitedAllowance,
      hasAllowance,
      userBalance,
    },
    contracts: {
      customSender: addresses.customSender,
      oraclePool: addresses.oraclePool,
      priceOracle: addresses.priceOracle,
      wnative: addresses.wnative,
      linkToken: addresses.linkToken,
    },
    metadata: {
      chainKey,
      protocolName: protocol.name,
    },
  };
}
