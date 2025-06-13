/**
 * @fileoverview Fee Estimation Module
 *
 * This module combines fee calculation and encoding logic to provide complete
 * fee estimation for slowStake operations. It coordinates between the pure
 * calculation module and the encoding module.
 *
 * This replaces the original mixed logic in estimateFees.ts with a clean,
 * composable architecture that enables reuse for both estimation and execution.
 */

import { formatEther, ZeroAddress } from 'ethers';
import type { SupportedChainId } from '@/types';
import type { PaymentMethod, CCIPFeePaymentMethod } from '@/config';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import { getCCIPChainSelector } from '@/config/ccip';
import {
  ETHEREUM_MAINNET,
  isProtocolSupportedOnChain,
  SLOWSTAKE_GAS_LIMIT_MULTIPLIER,
} from '@/config';
import type { ProtocolConfig } from '@/core/protocols/interfaces';

// Import calculation functions
import {
  calculateCCIPFee,
  calculateBridgeFee,
  calculateGasLimit,
  validateCCIPFeeParams,
  validateBridgeFeeParams,
  type CCIPFeeCalculationParams,
  type BridgeFeeCalculationResult,
} from './fee-calculator';

// Import encoding functions
import {
  encodeCCIPFee,
  encodeArbitrumL1toL2Fee,
  encodeOptimismL1toL2Fee,
  encodeBaseL1toL2Fee,
  type CCIPFeeParams,
  type ArbitrumL1toL2FeeParams,
  type OptimismL1toL2FeeParams,
} from './fee-codec';

/**
 * Parameters for slowStake fee estimation
 */
export interface EstimateSlowStakeFeesParams {
  /** Supported chain ID for operations */
  readonly chainKey: SupportedChainId;
  /** Amount to stake, in wei */
  readonly stakingAmount: bigint;
  /** Payment method for staking: 'native' for ETH, 'wrapped' for WETH */
  readonly paymentMethod: PaymentMethod;
  /** Fee payment method for CCIP: 'native' for ETH, 'link' for LINK token */
  readonly ccipFeePaymentMethod: CCIPFeePaymentMethod;
  /** Protocol configuration to use */
  readonly protocol: ProtocolConfig;
}

/**
 * CCIP fee estimation result with encoding
 */
export interface CCIPFeeEstimation {
  readonly estimated: bigint;
  readonly encoded: string;
  readonly breakdown: {
    readonly maxFee: bigint;
    readonly payInLink: boolean;
    readonly gasLimit: number;
  };
}

/**
 * Bridge fee estimation result with encoding
 */
export interface BridgeFeeEstimation {
  readonly estimated: bigint;
  readonly encoded: string;
  readonly breakdown: {
    readonly bridgeType: string;
    readonly arbitrum?: {
      readonly maxSubmissionCost: bigint;
      readonly maxGas: number;
      readonly gasPriceBid: bigint;
    };
    readonly optimism?: {
      readonly l2Gas: number;
    };
    readonly base?: {
      readonly l2Gas: number;
    };
  };
}

/**
 * Complete fee estimation result for slowStake
 */
export interface SlowStakeFeeEstimation {
  readonly stakingAmount: bigint;
  readonly paymentMethod: PaymentMethod;
  readonly ccipFeePaymentMethod: CCIPFeePaymentMethod;
  readonly feeOtoD: CCIPFeeEstimation;
  readonly feeDtoO: BridgeFeeEstimation;
  readonly requirements: {
    readonly ethRequired: bigint; // Staking amount + bridge fees (always in ETH)
    readonly linkRequired: bigint; // CCIP fees when paying in LINK (0 when paying in ETH)
  };
  readonly contracts: {
    readonly customSender: string;
    readonly linkToken: string;
    readonly wnative: string;
    readonly ccipRouter: string;
  };
  readonly summary: {
    readonly stakingAmountFormatted: string;
    readonly feeOtoDFormatted: string;
    readonly feeOtoDToken: string; // 'ETH' or 'LINK'
    readonly feeDtoOFormatted: string;
    readonly ethRequiredFormatted: string;
    readonly linkRequiredFormatted: string;
  };
}

// Gas limit multiplier is now imported from centralized config

/**
 * Protocol-agnostic slowStake fee estimator with clean separation of concerns.
 *
 * This function coordinates between:
 * - Fee calculation (pure numerical logic)
 * - Fee encoding (matching Solidity FeeCodec.sol)
 * - Contract setup and validation
 *
 * @param params Fee estimation parameters
 * @returns Complete fee breakdown with encoded fee data
 * @throws Error if slowStake not supported on the chain
 */
export async function estimateSlowStakeFees(
  params: EstimateSlowStakeFeesParams
): Promise<SlowStakeFeeEstimation> {
  const {
    chainKey,
    stakingAmount,
    paymentMethod,
    ccipFeePaymentMethod,
    protocol,
  } = params;

  // Validate slowStake support
  if (!isProtocolSupportedOnChain(protocol, chainKey)) {
    throw new Error(
      `SlowStake not supported on ${chainKey}. Only available on L2 chains.`
    );
  }

  // Setup contracts using the protocol-agnostic utility
  const setup = await setupLiquidStakingContracts({ chainKey, protocol });
  const { addresses, contracts, provider } = setup;

  // Get contract parameters
  const [ccipRouterAddress, minProcessMessageGas] = await Promise.all([
    contracts.customSender.CCIP_ROUTER(),
    contracts.customSender.MIN_PROCESS_MESSAGE_GAS(),
  ]);

  // Calculate gas limit based on contract's minimum requirement
  const gasLimit = calculateGasLimit(
    minProcessMessageGas,
    SLOWSTAKE_GAS_LIMIT_MULTIPLIER
  );

  // For CCIP fee estimation, always use WNATIVE address
  // The contract wraps native ETH to WNATIVE before sending via CCIP
  const tokenAddress = addresses.wnative;

  // Calculate CCIP fees (Origin → Destination)
  const ccipCalculationParams: CCIPFeeCalculationParams = {
    ccipRouterAddress,
    tokenAddress,
    linkTokenAddress: addresses.linkToken,
    stakingAmount,
    payInLink: ccipFeePaymentMethod === 'link',
    gasLimit,
    provider,
    customSenderContract: contracts.customSender,
    sourceChainKey: chainKey,
  };

  validateCCIPFeeParams(ccipCalculationParams);
  const ccipFeeResult = await calculateCCIPFee(ccipCalculationParams);

  // Encode CCIP fee data
  const ccipFeeParams: CCIPFeeParams = {
    maxFee: ccipFeeResult.maxFee,
    payInLink: ccipFeeResult.payInLink,
    gasLimit: ccipFeeResult.gasLimit,
  };
  const encodedCCIPFee = encodeCCIPFee(ccipFeeParams);

  // Calculate bridge fees (Destination → Origin)
  const bridgeFeeParams = { chainKey };
  validateBridgeFeeParams(bridgeFeeParams);
  const bridgeFeeResult = calculateBridgeFee(bridgeFeeParams);

  // Encode bridge fee data based on bridge type
  const encodedBridgeFee = encodeBridgeFeeData(bridgeFeeResult);

  // Calculate requirements based on payment method
  const ethRequired =
    ccipFeePaymentMethod === 'link'
      ? stakingAmount + bridgeFeeResult.estimatedFee // Only staking + bridge fees
      : stakingAmount +
        bridgeFeeResult.estimatedFee +
        ccipFeeResult.bufferedFee; // All in ETH

  const linkRequired =
    ccipFeePaymentMethod === 'link'
      ? ccipFeeResult.bufferedFee // CCIP fee in LINK
      : 0n; // No LINK needed

  // Build result with proper typing
  const feeOtoD: CCIPFeeEstimation = {
    estimated: ccipFeeResult.bufferedFee,
    encoded: encodedCCIPFee,
    breakdown: {
      maxFee: ccipFeeResult.maxFee,
      payInLink: ccipFeeResult.payInLink,
      gasLimit: ccipFeeResult.gasLimit,
    },
  };

  const feeDtoO: BridgeFeeEstimation = {
    estimated: bridgeFeeResult.estimatedFee,
    encoded: encodedBridgeFee,
    breakdown: buildBridgeFeeBreakdown(bridgeFeeResult),
  };

  return {
    stakingAmount,
    paymentMethod,
    ccipFeePaymentMethod,
    feeOtoD,
    feeDtoO,
    requirements: {
      ethRequired,
      linkRequired,
    },
    contracts: {
      customSender: addresses.customSender,
      linkToken: addresses.linkToken,
      wnative: addresses.wnative,
      ccipRouter: ccipRouterAddress,
    },
    summary: {
      stakingAmountFormatted: formatEther(stakingAmount),
      feeOtoDFormatted: formatEther(feeOtoD.estimated),
      feeOtoDToken: ccipFeePaymentMethod === 'link' ? 'LINK' : 'ETH',
      feeDtoOFormatted: formatEther(feeDtoO.estimated),
      ethRequiredFormatted: formatEther(ethRequired),
      linkRequiredFormatted: formatEther(linkRequired),
    },
  };
}

/**
 * Encodes bridge fee data based on bridge type
 *
 * @param bridgeFeeResult Bridge fee calculation result
 * @returns Encoded bridge fee data
 */
function encodeBridgeFeeData(
  bridgeFeeResult: BridgeFeeCalculationResult
): string {
  if (bridgeFeeResult.bridgeType === 'arbitrum') {
    const params = bridgeFeeResult.parameters as ArbitrumL1toL2FeeParams;
    const arbParams: ArbitrumL1toL2FeeParams = {
      maxSubmissionCost: params.maxSubmissionCost,
      maxGas: params.maxGas,
      gasPriceBid: params.gasPriceBid,
    };
    return encodeArbitrumL1toL2Fee(arbParams);
  }

  if (bridgeFeeResult.bridgeType === 'optimism') {
    const params = bridgeFeeResult.parameters as OptimismL1toL2FeeParams;
    const opParams: OptimismL1toL2FeeParams = {
      l2Gas: params.l2Gas,
    };
    return encodeOptimismL1toL2Fee(opParams);
  }

  if (bridgeFeeResult.bridgeType === 'base') {
    const params = bridgeFeeResult.parameters as OptimismL1toL2FeeParams;
    const baseParams: OptimismL1toL2FeeParams = {
      l2Gas: params.l2Gas,
    };
    return encodeBaseL1toL2Fee(baseParams);
  }

  throw new Error(`Unsupported bridge type: ${bridgeFeeResult.bridgeType}`);
}

/**
 * Builds bridge fee breakdown for the result interface
 *
 * @param bridgeFeeResult Bridge fee calculation result
 * @returns Bridge fee breakdown
 */
function buildBridgeFeeBreakdown(
  bridgeFeeResult: BridgeFeeCalculationResult
): BridgeFeeEstimation['breakdown'] {
  const bridgeType = bridgeFeeResult.bridgeType;

  if (bridgeType === 'arbitrum') {
    const params = bridgeFeeResult.parameters as ArbitrumL1toL2FeeParams;
    return {
      bridgeType,
      arbitrum: {
        maxSubmissionCost: params.maxSubmissionCost,
        maxGas: params.maxGas,
        gasPriceBid: params.gasPriceBid,
      },
    };
  }

  if (bridgeType === 'optimism') {
    const params = bridgeFeeResult.parameters as OptimismL1toL2FeeParams;
    return {
      bridgeType,
      optimism: {
        l2Gas: params.l2Gas,
      },
    };
  }

  if (bridgeType === 'base') {
    const params = bridgeFeeResult.parameters as OptimismL1toL2FeeParams;
    return {
      bridgeType,
      base: {
        l2Gas: params.l2Gas,
      },
    };
  }

  throw new Error(`Unsupported bridge type: ${bridgeType}`);
}

/**
 * Extracts raw fee data for contract execution
 *
 * This function provides the encoded fee data that can be directly
 * used in slowStake contract calls, enabling reuse of estimation
 * results for execution.
 *
 * @param estimation Fee estimation result
 * @returns Raw fee data for contract calls
 */
export function extractContractFeeData(estimation: SlowStakeFeeEstimation): {
  feeOtoD: string;
  feeDtoO: string;
  ethRequired: bigint;
  linkRequired: bigint;
  destChainSelector: string;
  tokenAddress: string;
  amount: bigint;
} {
  return {
    feeOtoD: estimation.feeOtoD.encoded,
    feeDtoO: estimation.feeDtoO.encoded,
    ethRequired: estimation.requirements.ethRequired,
    linkRequired: estimation.requirements.linkRequired,
    destChainSelector: getCCIPChainSelector(ETHEREUM_MAINNET),
    // For contract execution: ZeroAddress = native ETH, WNATIVE = wrapped ETH
    tokenAddress:
      estimation.paymentMethod === 'native'
        ? ZeroAddress
        : estimation.contracts.wnative,
    amount: estimation.stakingAmount,
  };
}
