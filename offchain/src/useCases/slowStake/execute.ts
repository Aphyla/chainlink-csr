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
import { MaxUint256 } from 'ethers';
import type { SupportedChainId, Address } from '@/types';
import type { CCIPFeePaymentMethod, PaymentMethod } from '@/config';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import { getCCIPChainSelector } from '@/config/ccip';
import { ETHEREUM_MAINNET, NUMBER_BLOCKS_TO_WAIT } from '@/config';
import type { ProtocolConfig } from '@/core/protocols/interfaces';
import { checkTokenAllowance } from '@/useCases/allowance/check';
import { IERC20__factory, CustomSender__factory } from '@/generated/typechain';
import type { TransactionReceipt } from 'ethers';
import { formatUnits } from 'ethers';

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
  readonly ccipFeePaymentMethod: CCIPFeePaymentMethod;
  /** Protocol configuration to use */
  readonly protocol: ProtocolConfig;
  /** Signer to execute the transaction */
  readonly signer: Signer;
  /** Optional recipient address (defaults to signer address) */
  readonly recipient?: string;
  /** Whether to use pre-calculated fee estimation (optional optimization) */
  readonly feeEstimation?: SlowStakeFeeEstimation;
  /** Whether to auto-approve unlimited allowance for tokens (default: false) */
  readonly autoApproveUnlimited?: boolean;
}

/**
 * Allowance information for a specific token.
 */
export interface TokenAllowanceInfo {
  /** Whether allowance was checked for this token. */
  readonly checked: boolean;
  /** Token address that was checked. */
  readonly tokenAddress: Address;
  /** Token symbol from contract (e.g., 'WETH', 'LINK'). */
  readonly tokenSymbol: string;
  /** Initial allowance before any changes. */
  readonly initialAllowance: bigint;
  /** Whether approval transaction was needed. */
  readonly approvalNeeded: boolean;
  /** Approval transaction hash if approval was executed. */
  readonly approvalTxHash?: string;
  /** Final allowance after approval (if any). */
  readonly finalAllowance: bigint;
}

/**
 * Comprehensive allowance management information.
 */
export interface AllowanceManagementInfo {
  /** WETH token allowance information (for wrapped payments). */
  readonly weth: TokenAllowanceInfo;
  /** LINK token allowance information (for LINK CCIP fees). */
  readonly link: TokenAllowanceInfo;
}

/**
 * Decoded SlowStake event information.
 */
export interface SlowStakeEventInfo {
  /** User address from the event. */
  readonly user: Address;
  /** Destination chain selector from the event. */
  readonly destChainSelector: string;
  /** CCIP message ID from the event. */
  readonly messageId: string;
  /** Token address from the event. */
  readonly token: Address;
  /** Amount from the event, in wei. */
  readonly amount: bigint;
  /** Formatted amount for display. */
  readonly formattedAmount: string;
}

/**
 * Result of slowStake execution
 */
export interface SlowStakeExecutionResult {
  readonly transactionHash: string;
  readonly messageId: string;
  readonly feeEstimation: SlowStakeFeeEstimation;
  readonly allowanceManagement: AllowanceManagementInfo;
  readonly slowStakeEvent: SlowStakeEventInfo;
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
 * 2. Handles allowance management for both WETH and LINK tokens
 * 3. Builds the exact contract call parameters
 * 4. Executes the transaction with proper error handling
 *
 * @param params Execution parameters
 * @returns Execution result with transaction details and allowance info
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
    autoApproveUnlimited = false,
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

  const signerAddress = await signer.getAddress();

  // Check all required token balances first
  console.log('💰 Checking token balances...');
  await checkAllRequiredBalances({
    chainKey,
    stakingAmount,
    paymentMethod,
    ccipFeePaymentMethod,
    feeEstimation,
    signerAddress,
    setup,
    signer,
  });

  // Handle allowance management
  console.log('🔐 Managing token allowances...');

  // 1. Handle WETH allowance (if using wrapped payment)
  let wethAllowanceInfo: TokenAllowanceInfo;

  if (paymentMethod === 'wrapped') {
    console.log('🔐 Checking wrapped token allowance for wrapped payment...');

    const allowanceResult = await checkTokenAllowance({
      chainKey,
      userAddress: signerAddress,
      protocol,
    });

    const initialAllowance = allowanceResult.allowanceInfo.allowance;
    const tokenSymbol = allowanceResult.allowanceInfo.token.symbol;
    const tokenAddress = allowanceResult.allowanceInfo.tokenAddress;

    if (allowanceResult.allowanceInfo.allowance < stakingAmount) {
      console.log(`📝 Insufficient ${tokenSymbol} allowance. Approving...`);

      const tokenContract = setup.contracts.tokenIn.connect(signer);
      const approveAmount = autoApproveUnlimited ? MaxUint256 : stakingAmount;

      const approveTx = await tokenContract.approve(
        setup.addresses.customSender,
        approveAmount
      );

      console.log(
        `⏳ Waiting for ${tokenSymbol} approval transaction: ${approveTx.hash}`
      );
      await approveTx.wait(NUMBER_BLOCKS_TO_WAIT);

      wethAllowanceInfo = {
        checked: true,
        tokenAddress,
        tokenSymbol,
        initialAllowance,
        approvalNeeded: true,
        approvalTxHash: approveTx.hash,
        finalAllowance: approveAmount,
      };

      console.log(`✅ ${tokenSymbol} approval completed`);
    } else {
      wethAllowanceInfo = {
        checked: true,
        tokenAddress,
        tokenSymbol,
        initialAllowance,
        approvalNeeded: false,
        finalAllowance: allowanceResult.allowanceInfo.allowance,
      };
      console.log(`✅ Sufficient ${tokenSymbol} allowance already exists`);
    }
  } else {
    wethAllowanceInfo = {
      checked: false,
      tokenAddress: setup.addresses.wnative,
      tokenSymbol: 'ETH',
      initialAllowance: 0n,
      approvalNeeded: false,
      finalAllowance: 0n,
    };
  }

  // 2. Handle LINK allowance (if using LINK for CCIP fees)
  let linkAllowanceInfo: TokenAllowanceInfo;

  if (ccipFeePaymentMethod === 'link') {
    console.log('🔗 Checking LINK allowance for CCIP fees...');

    const linkContract = IERC20__factory.connect(
      setup.addresses.linkToken,
      signer
    );

    const [initialAllowance, linkSymbol] = await Promise.all([
      linkContract.allowance(signerAddress, setup.addresses.customSender),
      linkContract.symbol(),
    ]);

    if (initialAllowance < feeEstimation.requirements.linkRequired) {
      console.log(`📝 Insufficient ${linkSymbol} allowance. Approving...`);

      const approveAmount = autoApproveUnlimited
        ? MaxUint256
        : feeEstimation.requirements.linkRequired;

      const approveTx = await linkContract.approve(
        setup.addresses.customSender,
        approveAmount
      );

      console.log(
        `⏳ Waiting for ${linkSymbol} approval transaction: ${approveTx.hash}`
      );
      await approveTx.wait(NUMBER_BLOCKS_TO_WAIT);

      linkAllowanceInfo = {
        checked: true,
        tokenAddress: setup.addresses.linkToken,
        tokenSymbol: linkSymbol,
        initialAllowance,
        approvalNeeded: true,
        approvalTxHash: approveTx.hash,
        finalAllowance: approveAmount,
      };

      console.log(`✅ ${linkSymbol} approval completed`);
    } else {
      linkAllowanceInfo = {
        checked: true,
        tokenAddress: setup.addresses.linkToken,
        tokenSymbol: linkSymbol,
        initialAllowance,
        approvalNeeded: false,
        finalAllowance: initialAllowance,
      };
      console.log(`✅ Sufficient ${linkSymbol} allowance already exists`);
    }
  } else {
    linkAllowanceInfo = {
      checked: false,
      tokenAddress: setup.addresses.linkToken,
      tokenSymbol: 'LINK',
      initialAllowance: 0n,
      approvalNeeded: false,
      finalAllowance: 0n,
    };
  }

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

  console.log('🚀 Executing slowStake transaction...');

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

  console.log(`⏳ Transaction submitted: ${tx.hash}`);
  console.log(`📊 Waiting for confirmation...`);

  // Wait for transaction confirmation and extract messageId
  const receipt = await tx.wait(NUMBER_BLOCKS_TO_WAIT);
  if (!receipt) {
    throw new Error('Transaction failed: no receipt received');
  }

  console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);

  // Get token decimals for formatting
  const tokenDecimals = await setup.contracts.tokenIn.decimals();

  // Decode the SlowStake event
  const slowStakeEventInfo = decodeSlowStakeEvent(
    receipt,
    setup.addresses.customSender,
    Number(tokenDecimals)
  );

  return {
    transactionHash: tx.hash,
    messageId: slowStakeEventInfo.messageId,
    feeEstimation,
    allowanceManagement: {
      weth: wethAllowanceInfo,
      link: linkAllowanceInfo,
    },
    slowStakeEvent: slowStakeEventInfo,
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
 * @param receipt - Transaction receipt to parse
 * @param customSenderAddress - CustomSender contract address for filtering
 * @param tokenDecimals - Token decimals for proper formatting
 * @returns Decoded SlowStake event information
 * @throws Error if SlowStake event not found
 */
function decodeSlowStakeEvent(
  receipt: TransactionReceipt,
  customSenderAddress: Address,
  tokenDecimals: number
): SlowStakeEventInfo {
  // Create interface instance for event parsing
  const customSenderInterface = CustomSender__factory.createInterface();
  const slowStakeEvent = customSenderInterface.getEvent('SlowStake');

  // Find and parse the SlowStake event from the logs
  for (const log of receipt.logs) {
    // Only process logs from the CustomSender contract
    if (log.address.toLowerCase() !== customSenderAddress.toLowerCase()) {
      continue;
    }

    try {
      // Use modern parseLog method - much safer than manual parsing
      const parsed = customSenderInterface.parseLog({
        topics: log.topics,
        data: log.data,
      });

      // Check if this is the SlowStake event we're looking for
      if (parsed && parsed.name === slowStakeEvent.name) {
        return {
          user: parsed.args.user as string,
          destChainSelector: parsed.args.destChainSelector.toString(),
          messageId: parsed.args.messageId as string,
          token: parsed.args.token as string,
          amount: parsed.args.amount as bigint,
          formattedAmount: formatUnits(parsed.args.amount, tokenDecimals),
        };
      }
    } catch {
      // Continue to next log if this one doesn't match
      continue;
    }
  }

  throw new Error('SlowStake event not found in transaction receipt');
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

/**
 * Checks all required token balances before execution
 * @param params Balance check parameters
 * @throws Error with specific balance information if insufficient
 */
async function checkAllRequiredBalances(params: {
  chainKey: SupportedChainId;
  stakingAmount: bigint;
  paymentMethod: PaymentMethod;
  ccipFeePaymentMethod: CCIPFeePaymentMethod;
  feeEstimation: SlowStakeFeeEstimation;
  signerAddress: Address;
  setup: Awaited<ReturnType<typeof setupLiquidStakingContracts>>;
  signer: Signer;
}): Promise<void> {
  const {
    stakingAmount,
    paymentMethod,
    ccipFeePaymentMethod,
    feeEstimation,
    signerAddress,
    setup,
    signer,
  } = params;

  const errors: string[] = [];

  // 1. Check ETH balance (always needed for gas and potentially fees)
  const ethBalance = await signer.provider!.getBalance(signerAddress);
  const ethRequired = feeEstimation.requirements.ethRequired;

  if (ethBalance < ethRequired) {
    const shortfall = ethRequired - ethBalance;
    errors.push(
      `Insufficient ETH balance. Required: ${formatUnits(ethRequired, 18)} ETH, ` +
        `Available: ${formatUnits(ethBalance, 18)} ETH, ` +
        `Shortfall: ${formatUnits(shortfall, 18)} ETH`
    );
  } else {
    console.log(
      `✅ ETH balance sufficient: ${formatUnits(ethBalance, 18)} ETH (required: ${formatUnits(ethRequired, 18)} ETH)`
    );
  }

  // 2. Check WETH balance (if using wrapped payment for staking)
  if (paymentMethod === 'wrapped') {
    const wethContract = setup.contracts.tokenIn;
    const [wethBalance, wethSymbol] = await Promise.all([
      wethContract.balanceOf(signerAddress),
      wethContract.symbol(),
    ]);

    if (wethBalance < stakingAmount) {
      const shortfall = stakingAmount - wethBalance;
      errors.push(
        `Insufficient ${wethSymbol} balance. Required: ${formatUnits(stakingAmount, 18)} ${wethSymbol}, ` +
          `Available: ${formatUnits(wethBalance, 18)} ${wethSymbol}, ` +
          `Shortfall: ${formatUnits(shortfall, 18)} ${wethSymbol}`
      );
    } else {
      console.log(
        `✅ ${wethSymbol} balance sufficient: ${formatUnits(wethBalance, 18)} ${wethSymbol} (required: ${formatUnits(stakingAmount, 18)} ${wethSymbol})`
      );
    }
  }

  // 3. Check LINK balance (if using LINK for CCIP fees)
  if (ccipFeePaymentMethod === 'link') {
    const linkContract = IERC20__factory.connect(
      setup.addresses.linkToken,
      signer
    );
    const [linkBalance, linkSymbol] = await Promise.all([
      linkContract.balanceOf(signerAddress),
      linkContract.symbol(),
    ]);

    const linkRequired = feeEstimation.requirements.linkRequired;

    if (linkBalance < linkRequired) {
      const shortfall = linkRequired - linkBalance;
      errors.push(
        `Insufficient ${linkSymbol} balance. Required: ${formatUnits(linkRequired, 18)} ${linkSymbol}, ` +
          `Available: ${formatUnits(linkBalance, 18)} ${linkSymbol}, ` +
          `Shortfall: ${formatUnits(shortfall, 18)} ${linkSymbol}`
      );
    } else {
      console.log(
        `✅ ${linkSymbol} balance sufficient: ${formatUnits(linkBalance, 18)} ${linkSymbol} (required: ${formatUnits(linkRequired, 18)} ${linkSymbol})`
      );
    }
  }

  // If any balance is insufficient, throw a detailed error
  if (errors.length > 0) {
    throw new Error(
      `Insufficient token balance(s):\n\n${errors.map(err => `• ${err}`).join('\n')}\n\n` +
        `Please ensure you have sufficient balances before retrying.`
    );
  }
}
