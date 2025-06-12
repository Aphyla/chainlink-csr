import { ZeroAddress, parseUnits, formatUnits, MaxUint256 } from 'ethers';
import type { Wallet, TransactionReceipt } from 'ethers';
import type { Address, SupportedChainId } from '@/types';
import type { PaymentMethod, SlippageTolerance } from '@/config';
import { NUMBER_BLOCKS_TO_WAIT, DEFAULT_SLIPPAGE_TOLERANCE } from '@/config';
import { setupLiquidStakingContracts } from '@/core/contracts/setup';
import { checkTokenAllowance } from '@/useCases/allowance/check';
import { estimateFastStake } from './estimate';
import type { ProtocolConfig } from '@/core/protocols/interfaces';
import { CustomSenderReferral__factory } from '@/generated/typechain';

/**
 * Parameters accepted by {@link executeFastStakeReferral}.
 */
export interface ExecuteFastStakeReferralParams {
  /** Supported chain ID for operations. */
  readonly chainKey: SupportedChainId;
  /** Wallet instance for signing transactions. */
  readonly wallet: Wallet;
  /** Amount to stake, in wei. */
  readonly amountIn: bigint;
  /** Payment method: 'native' for ETH, 'wrapped' for WETH. */
  readonly paymentMethod: PaymentMethod;
  /** Referral address for tracking. */
  readonly referralAddress: Address;
  /** Protocol configuration to use. */
  readonly protocol: ProtocolConfig;
  /** Optional slippage tolerance (default: 1% = 0.01). */
  readonly slippageTolerance?: SlippageTolerance;
  /** Whether to auto-approve unlimited allowance for wrapped tokens (default: false). */
  readonly autoApproveUnlimited?: boolean;
}

/**
 * Allowance information and actions taken.
 */
export interface AllowanceInfo {
  /** Whether allowance was checked (only for wrapped payments). */
  readonly checked: boolean;
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
 * Transaction execution details.
 */
export interface TransactionInfo {
  /** Transaction hash of the fastStakeReferral call. */
  readonly txHash: string;
  /** Gas used for the transaction. */
  readonly gasUsed: bigint;
  /** Effective gas price paid. */
  readonly gasPrice: bigint;
  /** Total gas cost in wei. */
  readonly gasCost: bigint;
  /** Block number where transaction was mined. */
  readonly blockNumber: number;
}

/**
 * Decoded Referral event information.
 */
export interface ReferralEventInfo {
  /** User address from the event. */
  readonly user: Address;
  /** Referral address from the event. */
  readonly referral: Address;
  /** Amount out from the event, in wei. */
  readonly amountOut: bigint;
  /** Formatted amount out for display. */
  readonly formattedAmountOut: string;
}

/**
 * Result returned by {@link executeFastStakeReferral}.
 */
export interface ExecuteFastStakeReferralResult {
  /** Execution success status. */
  readonly success: boolean;
  /** Estimated parameters used for the transaction. */
  readonly estimation: Awaited<ReturnType<typeof estimateFastStake>>;
  /** Allowance management details. */
  readonly allowance: AllowanceInfo;
  /** Transaction execution information. */
  readonly transaction: TransactionInfo;
  /** Decoded Referral event data. */
  readonly referralEvent: ReferralEventInfo;
  /** Actual vs estimated amounts comparison. */
  readonly comparison: {
    readonly estimatedAmountOut: bigint;
    readonly actualAmountOut: bigint;
    readonly difference: bigint;
    readonly relativePerformance: number;
  };
}

/**
 * Protocol-agnostic fastStakeReferral executor.
 *
 * This function:
 * 1. Estimates the transaction to determine minAmountOut
 * 2. Handles allowance management for wrapped tokens
 * 3. Executes the fastStakeReferral transaction
 * 4. Decodes the Referral event from the receipt
 * 5. Provides comprehensive execution results
 *
 * The function supports both native ETH and wrapped token payments,
 * automatically handling the different flows and requirements.
 *
 * @param params - Execution parameters including wallet, amount, and payment method
 * @returns Complete execution results with transaction data and event information
 * @throws Error if execution fails or insufficient liquidity
 */
export async function executeFastStakeReferral(
  params: ExecuteFastStakeReferralParams
): Promise<ExecuteFastStakeReferralResult> {
  const {
    chainKey,
    wallet,
    amountIn,
    paymentMethod,
    referralAddress,
    protocol,
    slippageTolerance = DEFAULT_SLIPPAGE_TOLERANCE, // Use centralized default
    autoApproveUnlimited = false,
  } = params;

  // 1. Get estimation to determine minAmountOut and validate liquidity
  console.log('📊 Estimating transaction parameters...');
  const estimation = await estimateFastStake({
    chainKey,
    amountIn,
    protocol,
  });

  if (!estimation.pool.hasSufficientLiquidity) {
    throw new Error(
      `Insufficient pool liquidity. Need ${formatUnits(estimation.amountOut, estimation.contracts.tokenOut.decimals)} ${estimation.contracts.tokenOut.symbol}, ` +
        `but only ${formatUnits(estimation.pool.availableOut, estimation.contracts.tokenOut.decimals)} ${estimation.contracts.tokenOut.symbol} available.`
    );
  }

  // 2. Calculate minAmountOut with slippage protection
  const tokenDecimals = estimation.contracts.tokenOut.decimals;
  const slippageMultiplier = parseUnits(
    (1 - slippageTolerance).toString(),
    tokenDecimals
  );
  const minAmountOut =
    (estimation.amountOut * slippageMultiplier) /
    parseUnits('1', tokenDecimals);

  console.log(
    `✅ Estimation complete. Expected: ${formatUnits(estimation.amountOut, estimation.contracts.tokenOut.decimals)} ${estimation.contracts.tokenOut.symbol}`
  );
  console.log(
    `🛡️ Min amount out (${slippageTolerance * 100}% slippage): ${formatUnits(minAmountOut, estimation.contracts.tokenOut.decimals)} ${estimation.contracts.tokenOut.symbol}`
  );

  // 3. Setup contracts with wallet
  const setup = await setupLiquidStakingContracts({ chainKey, protocol });
  const customSender = setup.contracts.customSender.connect(wallet);

  // 4. Handle allowance for wrapped tokens
  let allowanceInfo: AllowanceInfo;

  if (paymentMethod === 'wrapped') {
    console.log('🔐 Checking TOKEN allowance for wrapped payment...');

    const allowanceResult = await checkTokenAllowance({
      chainKey,
      userAddress: wallet.address,
      protocol,
    });

    const initialAllowance = allowanceResult.allowanceInfo.allowance;

    // Check if approval is needed
    if (allowanceResult.allowanceInfo.allowance < amountIn) {
      console.log('📝 Insufficient allowance. Approving TOKEN...');

      const tokenContract = setup.contracts.tokenIn.connect(wallet);
      const approveAmount = autoApproveUnlimited ? MaxUint256 : amountIn;

      const approveTx = await tokenContract.approve(
        setup.addresses.customSender,
        approveAmount
      );

      console.log(`⏳ Waiting for approval transaction: ${approveTx.hash}`);
      await approveTx.wait(NUMBER_BLOCKS_TO_WAIT); // Wait for 3 blocks

      allowanceInfo = {
        checked: true,
        initialAllowance,
        approvalNeeded: true,
        approvalTxHash: approveTx.hash,
        finalAllowance: approveAmount,
      };

      console.log('✅ TOKEN approval completed');
    } else {
      allowanceInfo = {
        checked: true,
        initialAllowance,
        approvalNeeded: false,
        finalAllowance: allowanceResult.allowanceInfo.allowance,
      };
      console.log('✅ Sufficient allowance already exists');
    }
  } else {
    allowanceInfo = {
      checked: false,
      initialAllowance: 0n,
      approvalNeeded: false,
      finalAllowance: 0n,
    };
  }

  // 5. Determine token address and value based on payment method
  const tokenAddress =
    paymentMethod === 'native' ? ZeroAddress : setup.addresses.tokenIn;
  const txValue = paymentMethod === 'native' ? amountIn : 0n;

  console.log(
    `🚀 Executing fastStakeReferral with ${paymentMethod} payment...`
  );

  // 6. Execute the fastStakeReferral transaction
  const tx = await customSender.fastStakeReferral(
    tokenAddress,
    amountIn,
    minAmountOut,
    referralAddress,
    { value: txValue }
  );

  console.log(`⏳ Transaction submitted: ${tx.hash}`);
  console.log(`📊 Waiting for confirmation...`);

  // 7. Wait for transaction confirmation
  const receipt = await tx.wait(NUMBER_BLOCKS_TO_WAIT);
  if (!receipt) {
    throw new Error('Transaction failed - no receipt received');
  }

  console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);

  // 8. Decode the Referral event
  const referralEvent = decodeReferralEvent(
    receipt,
    setup.addresses.customSender,
    estimation.contracts.tokenOut.decimals
  );

  // 9. Build transaction info
  const transactionInfo: TransactionInfo = {
    txHash: receipt.hash,
    gasUsed: receipt.gasUsed,
    gasPrice: receipt.gasPrice,
    gasCost: receipt.gasUsed * receipt.gasPrice,
    blockNumber: receipt.blockNumber,
  };

  // 10. Calculate relative performance comparison
  const difference = referralEvent.amountOut - estimation.amountOut;
  const relativePerformance = Number(
    (referralEvent.amountOut * 10000n) / estimation.amountOut / 100n
  );

  return {
    success: true,
    estimation,
    allowance: allowanceInfo,
    transaction: transactionInfo,
    referralEvent,
    comparison: {
      estimatedAmountOut: estimation.amountOut,
      actualAmountOut: referralEvent.amountOut,
      difference,
      relativePerformance,
    },
  };
}

/**
 * @param receipt - Transaction receipt to parse
 * @param customSenderAddress - CustomSender contract address for filtering
 * @param tokenDecimals - Output token decimals for proper formatting
 * @returns Decoded referral event information
 * @throws Error if Referral event not found
 */
function decodeReferralEvent(
  receipt: TransactionReceipt,
  customSenderAddress: Address,
  tokenDecimals: number
): ReferralEventInfo {
  // Create interface instance for event parsing
  const referralInterface = CustomSenderReferral__factory.createInterface();
  const referralEvent = referralInterface.getEvent('Referral');

  // Find and parse the Referral event from the logs
  for (const log of receipt.logs) {
    // Only process logs from the CustomSender contract
    if (log.address.toLowerCase() !== customSenderAddress.toLowerCase()) {
      continue;
    }

    try {
      // Use modern parseLog method - much safer than manual parsing
      const parsed = referralInterface.parseLog({
        topics: log.topics,
        data: log.data,
      });

      // Check if this is the Referral event we're looking for
      if (parsed && parsed.name === referralEvent.name) {
        return {
          user: parsed.args.user as string,
          referral: parsed.args.referral as string,
          amountOut: parsed.args.amountOut as bigint,
          formattedAmountOut: formatUnits(parsed.args.amountOut, tokenDecimals),
        };
      }
    } catch {
      // Continue to next log if this one doesn't match
      continue;
    }
  }

  throw new Error('Referral event not found in transaction receipt');
}
