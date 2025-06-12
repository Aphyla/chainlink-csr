/**
 * @fileoverview SlowStake Executor Module
 *
 * This module provides functions to execute slowStake operations using
 * the fee estimation results. It demonstrates how to reuse the modular
 * fee estimation architecture for actual contract calls.
 *
 * This achieves the goal of avoiding duplication by reusing the same
 * fee calculation and encoding logic for both estimation and execution.
 */

import type { ContractTransactionResponse, Signer } from 'ethers';
import type { SupportedChainId } from '@/types';
import type { PaymentMethod } from '@/config';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import { getCCIPChainSelector } from '@/config/ccip';
import { ETHEREUM_MAINNET } from '@/config';
import type { ProtocolConfig } from '@/core/protocols/interfaces';

// Import fee estimation functions
import {
  estimateSlowStakeFees,
  extractContractFeeData,
  type SlowStakeFeeEstimation,
} from './estimate';

/**
 * Parameters for slowStake execution
 */
export interface ExecuteSlowStakeParams {
  /** Supported chain ID for operations */
  readonly chainKey: SupportedChainId;
  /** Amount to stake, in wei */
  readonly stakingAmount: bigint;
  /** Payment method for staking: 'native' for ETH, 'wrapped' for WETH */
  readonly paymentMethod: PaymentMethod;
  /** Fee payment method for CCIP: 'native' for ETH, 'link' for LINK token */
  readonly ccipFeePaymentMethod: 'native' | 'link';
  /** Protocol configuration to use */
  readonly protocol: ProtocolConfig;
  /** Signer to execute the transaction */
  readonly signer: Signer;
  /** Optional recipient address (defaults to signer address) */
  readonly recipient?: string;
  /** Whether to use pre-calculated fee estimation (optional optimization) */
  readonly feeEstimation?: SlowStakeFeeEstimation;
}

/**
 * Result of slowStake execution
 */
export interface SlowStakeExecutionResult {
  readonly transactionHash: string;
  readonly messageId: string;
  readonly feeEstimation: SlowStakeFeeEstimation;
  readonly contractCall: {
    readonly destChainSelector: string;
    readonly token: string;
    readonly amount: bigint;
    readonly feeOtoD: string;
    readonly feeDtoO: string;
    readonly totalValue: bigint;
  };
}

/**
 * Executes a slowStake operation with automatic fee estimation and encoding
 *
 * This function demonstrates the reusability of the fee estimation architecture:
 * 1. Uses the same fee calculation and encoding logic as estimation
 * 2. Builds the exact contract call parameters
 * 3. Executes the transaction with proper error handling
 *
 * @param params Execution parameters
 * @returns Execution result with transaction details
 */
export async function executeSlowStake(
  params: ExecuteSlowStakeParams
): Promise<SlowStakeExecutionResult> {
  const {
    chainKey,
    stakingAmount,
    paymentMethod,
    ccipFeePaymentMethod,
    protocol,
    signer,
    feeEstimation: providedEstimation,
  } = params;

  // Use provided estimation or calculate new one
  const feeEstimation =
    providedEstimation ||
    (await estimateSlowStakeFees({
      chainKey,
      stakingAmount,
      paymentMethod,
      ccipFeePaymentMethod,
      protocol,
    }));

  // Get contract instances
  const setup = await setupLiquidStakingContracts({
    chainKey,
    protocol,
  });
  const { contracts } = setup;

  // Connect contracts to signer
  const connectedContracts = {
    customSender: contracts.customSender.connect(signer),
  };

  // Extract contract call parameters from fee estimation
  const contractData = extractContractFeeData(feeEstimation);

  // Get destination chain selector
  const destChainSelector = getCCIPChainSelector(ETHEREUM_MAINNET);

  // Prepare contract call parameters
  const callParams = {
    destChainSelector: BigInt(destChainSelector),
    token: contractData.tokenAddress,
    amount: contractData.amount,
    feeOtoD: contractData.feeOtoD,
    feeDtoO: contractData.feeDtoO,
  };

  // Calculate total value to send with transaction (always ETH for contract calls)
  const totalValue = contractData.ethRequired;

  // Execute the slowStake transaction
  const tx: ContractTransactionResponse =
    await connectedContracts.customSender.slowStake(
      callParams.destChainSelector,
      callParams.token,
      callParams.amount,
      callParams.feeOtoD,
      callParams.feeDtoO,
      { value: totalValue }
    );

  // Wait for transaction confirmation and extract messageId
  const receipt = await tx.wait();
  if (!receipt) {
    throw new Error('Transaction failed: no receipt received');
  }

  // Extract messageId from SlowStake event
  const slowStakeEvent = receipt.logs.find(log => {
    try {
      const parsed = connectedContracts.customSender.interface.parseLog(log);
      return parsed?.name === 'SlowStake';
    } catch {
      return false;
    }
  });

  if (!slowStakeEvent) {
    throw new Error('SlowStake event not found in transaction receipt');
  }

  const parsedEvent =
    connectedContracts.customSender.interface.parseLog(slowStakeEvent);
  const messageId = parsedEvent?.args?.messageId;

  if (!messageId) {
    throw new Error('MessageId not found in SlowStake event');
  }

  return {
    transactionHash: tx.hash,
    messageId,
    feeEstimation,
    contractCall: {
      destChainSelector: destChainSelector,
      token: callParams.token,
      amount: callParams.amount,
      feeOtoD: callParams.feeOtoD,
      feeDtoO: callParams.feeDtoO,
      totalValue,
    },
  };
}

/**
 * Estimates fees and then executes slowStake in a single call
 *
 * This is a convenience function that combines estimation and execution.
 * Use this when you want to execute immediately after estimation.
 *
 * @param params Execution parameters (same as executeSlowStake)
 * @returns Execution result
 */
export async function estimateAndExecuteSlowStake(
  params: Omit<ExecuteSlowStakeParams, 'feeEstimation'>
): Promise<SlowStakeExecutionResult> {
  return executeSlowStake(params);
}

/**
 * Dry-run execution that validates parameters without sending transaction
 *
 * This function performs all the same steps as execution but uses
 * staticCall to validate the transaction would succeed without
 * actually sending it.
 *
 * @param params Execution parameters
 * @returns Validation result with estimated gas usage
 */
export async function validateSlowStakeExecution(
  params: ExecuteSlowStakeParams
): Promise<{
  valid: boolean;
  estimatedGas?: bigint;
  feeEstimation: SlowStakeFeeEstimation;
  error?: string;
}> {
  try {
    const {
      chainKey,
      stakingAmount,
      paymentMethod,
      ccipFeePaymentMethod,
      protocol,
      signer,
      feeEstimation: providedEstimation,
    } = params;

    // Use provided estimation or calculate new one
    const feeEstimation =
      providedEstimation ||
      (await estimateSlowStakeFees({
        chainKey,
        stakingAmount,
        paymentMethod,
        ccipFeePaymentMethod,
        protocol,
      }));

    // Get contract instances
    const setup = await setupLiquidStakingContracts({
      chainKey,
      protocol,
    });
    const { contracts } = setup;

    // Connect contracts to signer
    const connectedContracts = {
      customSender: contracts.customSender.connect(signer),
    };

    // Extract contract call parameters
    const contractData = extractContractFeeData(feeEstimation);
    const destChainSelector = getCCIPChainSelector(ETHEREUM_MAINNET);

    // Prepare contract call parameters
    const callParams = {
      destChainSelector: BigInt(destChainSelector),
      token: contractData.tokenAddress,
      amount: contractData.amount,
      feeOtoD: contractData.feeOtoD,
      feeDtoO: contractData.feeDtoO,
    };

    const totalValue = contractData.ethRequired;

    // Perform static call to validate transaction
    await connectedContracts.customSender.slowStake.staticCall(
      callParams.destChainSelector,
      callParams.token,
      callParams.amount,
      callParams.feeOtoD,
      callParams.feeDtoO,
      { value: totalValue }
    );

    // Estimate gas usage
    const estimatedGas =
      await connectedContracts.customSender.slowStake.estimateGas(
        callParams.destChainSelector,
        callParams.token,
        callParams.amount,
        callParams.feeOtoD,
        callParams.feeDtoO,
        { value: totalValue }
      );

    return {
      valid: true,
      estimatedGas,
      feeEstimation,
    };
  } catch (error) {
    return {
      valid: false,
      feeEstimation:
        params.feeEstimation ||
        (await estimateSlowStakeFees({
          chainKey: params.chainKey,
          stakingAmount: params.stakingAmount,
          paymentMethod: params.paymentMethod,
          ccipFeePaymentMethod: params.ccipFeePaymentMethod,
          protocol: params.protocol,
        })),
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Utility function to check if the signer has sufficient balance
 *
 * @param params Execution parameters
 * @returns Balance check result
 */
export async function checkSufficientBalance(
  params: Pick<
    ExecuteSlowStakeParams,
    | 'chainKey'
    | 'stakingAmount'
    | 'paymentMethod'
    | 'ccipFeePaymentMethod'
    | 'protocol'
    | 'signer'
  >
): Promise<{
  sufficient: boolean;
  required: bigint;
  available: bigint;
  shortfall?: bigint;
}> {
  const { signer } = params;

  // Get fee estimation
  const feeEstimation = await estimateSlowStakeFees({
    chainKey: params.chainKey,
    stakingAmount: params.stakingAmount,
    paymentMethod: params.paymentMethod,
    ccipFeePaymentMethod: params.ccipFeePaymentMethod,
    protocol: params.protocol,
  });

  const required = feeEstimation.requirements.ethRequired;
  const signerAddress = await signer.getAddress();

  // Check native token balance (ETH)
  const available = await signer.provider!.getBalance(signerAddress);

  const sufficient = available >= required;

  if (sufficient) {
    return {
      sufficient,
      required,
      available,
    };
  } else {
    return {
      sufficient,
      required,
      available,
      shortfall: required - available,
    };
  }
}
