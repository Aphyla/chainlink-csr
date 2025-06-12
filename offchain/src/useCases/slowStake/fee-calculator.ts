/**
 * @fileoverview Fee Calculation Module
 *
 * This module provides pure fee calculation functions for slowStake operations.
 * It separates calculation logic from encoding logic for better maintainability and testability.
 *
 * All functions in this module are pure (no side effects) and focus solely on numerical calculations.
 */

import type { Provider } from 'ethers';
import {
  ZeroAddress,
  isAddress,
  solidityPacked,
  id as keccakId,
  AbiCoder,
} from 'ethers';
import type { SupportedChainId } from '@/types';
import { getCCIPChainSelector, getBridgeConfig } from '@/config/ccip';
import { DEFAULT_BRIDGE_PARAMS } from '@/config/bridges';
import {
  ETHEREUM_MAINNET,
  SLOWSTAKE_FEE_BUFFER,
  SLOWSTAKE_GAS_LIMIT_MULTIPLIER,
  CCIP_FEE_ESTIMATION_PLACEHOLDER_RECIPIENT,
} from '@/config';
import {
  CCIPRouter__factory,
  type CustomSenderReferral,
} from '@/generated/typechain';

/**
 * Parameters for CCIP fee calculation
 */
export interface CCIPFeeCalculationParams {
  readonly ccipRouterAddress: string;
  readonly tokenAddress: string;
  readonly linkTokenAddress: string;
  readonly stakingAmount: bigint;
  readonly payInLink: boolean;
  readonly gasLimit: number;
  readonly provider: Provider;
  readonly customSenderContract: CustomSenderReferral;
  readonly sourceChainKey: SupportedChainId;
}

/**
 * CCIP fee calculation result
 */
export interface CCIPFeeCalculationResult {
  readonly estimatedFee: bigint;
  readonly bufferedFee: bigint;
  readonly maxFee: bigint;
  readonly payInLink: boolean;
  readonly gasLimit: number;
}

/**
 * Bridge fee calculation parameters
 */
export interface BridgeFeeCalculationParams {
  readonly chainKey: SupportedChainId;
}

/**
 * Bridge fee calculation result
 */
export interface BridgeFeeCalculationResult {
  readonly estimatedFee: bigint;
  readonly bridgeType: string;
  readonly parameters:
    | ArbitrumBridgeParams
    | OptimismBridgeParams
    | BaseBridgeParams;
}

/**
 * Arbitrum bridge parameters
 */
export interface ArbitrumBridgeParams {
  readonly type: 'arbitrum';
  readonly maxSubmissionCost: bigint;
  readonly maxGas: number;
  readonly gasPriceBid: bigint;
}

/**
 * Optimism bridge parameters
 */
export interface OptimismBridgeParams {
  readonly type: 'optimism';
  readonly l2Gas: number;
}

/**
 * Base bridge parameters
 */
export interface BaseBridgeParams {
  readonly type: 'base';
  readonly l2Gas: number;
}

// Fee buffer configuration is now imported from centralized config

/**
 * Calculates CCIP fees for origin-to-destination transfer
 *
 * This function performs the actual fee estimation by:
 * 1. Building a realistic CCIP message
 * 2. Querying the CCIP router for fee estimation
 * 3. Applying a buffer for fee fluctuations
 *
 * @param params CCIP fee calculation parameters
 * @returns CCIP fee calculation result with breakdown
 */
export async function calculateCCIPFee(
  params: CCIPFeeCalculationParams
): Promise<CCIPFeeCalculationResult> {
  const {
    ccipRouterAddress,
    tokenAddress,
    linkTokenAddress,
    stakingAmount,
    payInLink,
    gasLimit,
    provider,
    customSenderContract,
    sourceChainKey,
  } = params;

  // Create CCIP router contract instance
  const ccipRouter = CCIPRouter__factory.connect(ccipRouterAddress, provider);

  // Get destination chain selector (always Ethereum for slowStake)
  const destChainSelector = getCCIPChainSelector(ETHEREUM_MAINNET);

  // Get the actual receiver address from the contract
  const receiverBytes =
    await customSenderContract.getReceiver(destChainSelector);

  // Calculate bridge fee for destination-to-origin transfer (needed for data payload)
  const feeDtoOForData = calculateBridgeFee({ chainKey: sourceChainKey });
  const walletPlaceholder = CCIP_FEE_ESTIMATION_PLACEHOLDER_RECIPIENT;

  // Build encoded data for fee estimation (must match actual slowStake call)
  const encodedData = buildEncodedDataForEstimation(
    walletPlaceholder,
    stakingAmount,
    feeDtoOForData
  );

  // Build CCIP message for fee estimation
  const message = {
    receiver: receiverBytes,
    data: encodedData,
    tokenAmounts: [
      {
        token: tokenAddress,
        amount: stakingAmount.toString(),
      },
    ],
    feeToken: payInLink ? linkTokenAddress : ZeroAddress,
    extraArgs: buildExtraArgsForEstimation(gasLimit),
  };

  // Get fee estimate from CCIP router
  const estimatedFee = await ccipRouter.getFee(destChainSelector, message);

  // Apply buffer for fee fluctuations
  const bufferedFee =
    (estimatedFee * SLOWSTAKE_FEE_BUFFER.PERCENTAGE) /
    SLOWSTAKE_FEE_BUFFER.DIVISOR;

  return {
    estimatedFee,
    bufferedFee,
    maxFee: bufferedFee, // Use buffered fee as max fee
    payInLink,
    gasLimit,
  };
}

/**
 * Calculates bridge fees for destination-to-origin transfer
 *
 * This function determines the appropriate bridge type and calculates
 * the corresponding fee based on chain-specific parameters.
 *
 * @param params Bridge fee calculation parameters
 * @returns Bridge fee calculation result with breakdown
 */
export function calculateBridgeFee(
  params: BridgeFeeCalculationParams
): BridgeFeeCalculationResult {
  const { chainKey } = params;

  const bridgeConfig = getBridgeConfig(chainKey);
  const bridgeType = bridgeConfig.type;

  // Get default parameters for this bridge type
  const defaultParams =
    DEFAULT_BRIDGE_PARAMS[bridgeType as keyof typeof DEFAULT_BRIDGE_PARAMS];

  switch (bridgeType) {
    case 'arbitrum': {
      const arbParams = defaultParams as {
        maxSubmissionCost: bigint;
        maxGas: number;
        gasPriceBid: bigint;
      };

      const estimatedFee =
        arbParams.maxSubmissionCost +
        arbParams.gasPriceBid * BigInt(arbParams.maxGas);

      return {
        estimatedFee,
        bridgeType,
        parameters: {
          type: 'arbitrum',
          maxSubmissionCost: arbParams.maxSubmissionCost,
          maxGas: arbParams.maxGas,
          gasPriceBid: arbParams.gasPriceBid,
        },
      };
    }

    case 'optimism': {
      const opParams = defaultParams as { l2Gas: number; feeAmount?: bigint };

      return {
        estimatedFee: opParams.feeAmount ?? 0n,
        bridgeType,
        parameters: {
          type: 'optimism',
          l2Gas: opParams.l2Gas,
        },
      };
    }

    case 'base': {
      const baseParams = defaultParams as { l2Gas: number; feeAmount?: bigint };

      return {
        estimatedFee: baseParams.feeAmount ?? 0n,
        bridgeType,
        parameters: {
          type: 'base',
          l2Gas: baseParams.l2Gas,
        },
      };
    }

    default:
      throw new Error(`Unsupported bridge type: ${bridgeType}`);
  }
}

/**
 * Calculates gas limit based on contract's minimum requirement
 *
 * @param minProcessMessageGas Minimum gas from contract
 * @param multiplier Gas limit multiplier (default: from config)
 * @returns Calculated gas limit
 */
export function calculateGasLimit(
  minProcessMessageGas: bigint,
  multiplier: number = SLOWSTAKE_GAS_LIMIT_MULTIPLIER
): number {
  return Number(minProcessMessageGas) * multiplier;
}

/**
 * Builds encoded data for fee estimation
 *
 * This must match the exact format used in the actual slowStake call
 * to ensure accurate fee estimation.
 *
 * @param recipient Recipient address (placeholder for estimation)
 * @param amount Staking amount
 * @param bridgeFeeResult Bridge fee calculation result
 * @returns Encoded data as hex string
 */
function buildEncodedDataForEstimation(
  recipient: string,
  amount: bigint,
  bridgeFeeResult: BridgeFeeCalculationResult
): string {
  // This is a simplified encoding for fee estimation purposes only
  // The actual encoding will be done by the fee-codec module during execution
  return solidityPacked(
    ['address', 'uint256', 'uint256'],
    [recipient, amount, bridgeFeeResult.estimatedFee]
  );
}

/**
 * Builds extraArgs for CCIP message fee estimation
 *
 * This matches the EVMExtraArgsV2 structure used by CCIP.
 *
 * @param gasLimit Gas limit for destination chain execution
 * @returns Encoded extraArgs as hex string
 */
function buildExtraArgsForEstimation(gasLimit: number): string {
  // EVMExtraArgsV2 encoding:
  // selector = keccak256("CCIP EVMExtraArgsV2").slice(0,4)
  // args = abi.encode(uint256 gasLimit, bool allowOutOfOrderExecution)
  const selector = keccakId('CCIP EVMExtraArgsV2').slice(0, 10); // 0x + 8 chars
  const abiCoder = AbiCoder.defaultAbiCoder();
  const encodedArgs = abiCoder.encode(['uint256', 'bool'], [gasLimit, true]);
  return selector + encodedArgs.slice(2);
}

/**
 * Validates CCIP fee calculation parameters
 *
 * @param params Parameters to validate
 * @throws Error if parameters are invalid
 */
export function validateCCIPFeeParams(params: CCIPFeeCalculationParams): void {
  if (!isAddress(params.ccipRouterAddress)) {
    throw new Error('Invalid CCIP router address');
  }
  if (!isAddress(params.tokenAddress)) {
    throw new Error('Invalid token address');
  }
  if (!isAddress(params.linkTokenAddress)) {
    throw new Error('Invalid LINK token address');
  }
  if (params.stakingAmount <= 0n) {
    throw new Error('Staking amount must be positive');
  }
  if (params.gasLimit <= 0) {
    throw new Error('Gas limit must be positive');
  }
}

/**
 * Validates bridge fee calculation parameters
 *
 * @param params Parameters to validate
 * @throws Error if parameters are invalid
 */
export function validateBridgeFeeParams(
  params: BridgeFeeCalculationParams
): void {
  if (!params.chainKey) {
    throw new Error('Chain key is required');
  }

  try {
    getBridgeConfig(params.chainKey);
  } catch {
    throw new Error(
      `Unsupported chain for bridge operations: ${params.chainKey}`
    );
  }
}
