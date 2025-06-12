import { parseEther, formatEther, formatUnits, MaxUint256 } from 'ethers';
import {
  executeFastStakeReferral,
  LIDO_PROTOCOL,
  getNetworkConfig,
  createWallet,
  BASE_MAINNET,
} from '@/index';
import { pathToFileURL } from 'node:url';

/**
 * Example: Execute fastStakeReferral with wrapped native token (WETH) payment.
 * This demonstrates the full flow including allowance checking/approval,
 * staking WETH to receive liquid staking tokens, and comprehensive transaction monitoring.
 */
async function runExample(): Promise<void> {
  const chainKey = BASE_MAINNET;
  const network = getNetworkConfig(chainKey);

  console.log(`🚀 FastStake with Wrapped Native Token on ${network.name}`);
  console.log(`Explorer: ${network.explorer}`);
  console.log('');

  try {
    // Create wallet instance
    const wallet = createWallet(chainKey);
    console.log(`📱 Using wallet: ${wallet.address}`);

    // Transaction parameters
    const amountIn = parseEther('0.01'); // Stake 0.01 WETH (small amount for testing)
    const referralAddress = wallet.address; // Use own address as referral for simplicity
    const slippageTolerance = 0.02; // 2% slippage tolerance
    const autoApproveUnlimited = true; // Approve unlimited allowance for convenience

    console.log(`💰 Staking amount: ${formatEther(amountIn)} WETH`);
    console.log(`👥 Referral: ${referralAddress}`);
    console.log(`🛡️ Slippage tolerance: ${slippageTolerance * 100}%`);
    console.log(
      `🔓 Auto-approve unlimited: ${autoApproveUnlimited ? 'Yes' : 'No'}`
    );
    console.log('');

    // Execute the fastStakeReferral transaction
    console.log('🔄 Executing fastStakeReferral with WETH...');
    const result = await executeFastStakeReferral({
      chainKey,
      wallet,
      amountIn,
      paymentMethod: 'wrapped',
      referralAddress,
      protocol: LIDO_PROTOCOL,
      slippageTolerance,
      autoApproveUnlimited,
    });

    // Display comprehensive results
    console.log('');
    console.log('🎉 Transaction Successful!');
    console.log('═'.repeat(80));

    // Allowance Management (only for wrapped payments)
    if (result.allowance.checked) {
      console.log('🔐 Allowance Management:');
      console.log(
        `  Initial Allowance: ${formatEther(result.allowance.initialAllowance)} WETH`
      );

      if (result.allowance.approvalNeeded) {
        console.log('  ✅ Approval Required and Completed');
        console.log(`  Approval TX: ${result.allowance.approvalTxHash}`);
        console.log(
          `  Explorer: ${network.explorer}/tx/${result.allowance.approvalTxHash}`
        );

        if (result.allowance.finalAllowance === MaxUint256) {
          console.log('  Final Allowance: Unlimited (MaxUint256)');
        } else {
          console.log(
            `  Final Allowance: ${formatEther(result.allowance.finalAllowance)} WETH`
          );
        }
      } else {
        console.log('  ✅ Sufficient Allowance Already Existed');
        console.log(
          `  Current Allowance: ${formatEther(result.allowance.finalAllowance)} WETH`
        );
      }
      console.log('');
    }

    // Transaction Details
    console.log('📊 Transaction Details:');
    console.log(`  TX Hash: ${result.transaction.txHash}`);
    console.log(`  Block: ${result.transaction.blockNumber}`);
    console.log(`  Gas Used: ${result.transaction.gasUsed.toLocaleString()}`);
    console.log(
      `  Gas Price: ${formatUnits(result.transaction.gasPrice, 'gwei')} gwei`
    );
    console.log(`  Gas Cost: ${formatEther(result.transaction.gasCost)} ETH`);
    console.log(
      `  Explorer: ${network.explorer}/tx/${result.transaction.txHash}`
    );
    console.log('');

    // Input/Output Summary
    console.log('💱 Staking Summary:');
    console.log(`  Input: ${formatEther(amountIn)} WETH (wrapped)`);
    console.log(
      `  Output: ${result.referralEvent.formattedAmountOut} ${result.estimation.contracts.tokenOut.symbol}`
    );
    console.log(
      `  Effective Rate: ${formatUnits(result.estimation.effectiveRate, 18)} ${result.estimation.contracts.tokenOut.symbol}/WETH`
    );
    console.log('');

    // Fee Analysis
    console.log('💸 Fee Breakdown:');
    const feePercentage =
      Number((result.estimation.fees.feeRate * 10000n) / 10n ** 18n) / 100;
    console.log(`  Pool Fee: ${feePercentage}%`);
    console.log(
      `  Fee Amount: ${formatEther(result.estimation.fees.feeAmount)} ${result.estimation.contracts.tokenIn.symbol}`
    );
    console.log(
      `  Transaction Fee: ${formatEther(result.transaction.gasCost)} ETH`
    );

    if (result.allowance.approvalNeeded) {
      console.log('  💡 Note: Additional gas cost incurred for token approval');
    }
    console.log('');

    // Referral Event
    console.log('👥 Referral Event:');
    console.log(`  User: ${result.referralEvent.user}`);
    console.log(`  Referral: ${result.referralEvent.referral}`);
    console.log(
      `  Amount Out: ${result.referralEvent.formattedAmountOut} ${result.estimation.contracts.tokenOut.symbol}`
    );
    console.log('');

    // Performance Analysis
    console.log('🎯 Estimation vs Reality:');
    console.log(
      `  Estimated: ${formatUnits(result.comparison.estimatedAmountOut, result.estimation.contracts.tokenOut.decimals)} ${result.estimation.contracts.tokenOut.symbol}`
    );
    console.log(
      `  Actual: ${formatUnits(result.comparison.actualAmountOut, result.estimation.contracts.tokenOut.decimals)} ${result.estimation.contracts.tokenOut.symbol}`
    );
    console.log(
      `  Difference: ${formatUnits(result.comparison.difference, result.estimation.contracts.tokenOut.decimals)} ${result.estimation.contracts.tokenOut.symbol}`
    );
    console.log(
      `  Relative Performance: ${result.comparison.relativePerformance.toFixed(2)}%`
    );
    console.log('');

    // Contract Information
    console.log('📋 Contract Details:');
    console.log(`  CustomSender: ${result.estimation.contracts.customSender}`);
    console.log(`  OraclePool: ${result.estimation.contracts.oraclePool}`);
    console.log(`  PriceOracle: ${result.estimation.contracts.priceOracle}`);
    console.log(
      `  Input Token: ${result.estimation.contracts.tokenIn.symbol} (${result.estimation.contracts.tokenIn.address})`
    );
    console.log(
      `  Output Token: ${result.estimation.contracts.tokenOut.symbol} (${result.estimation.contracts.tokenOut.address})`
    );
    console.log('');
  } catch (error) {
    console.error('❌ FastStake execution failed:');
    console.error(`   ${error instanceof Error ? error.message : error}`);
    console.error(
      '💡 Check wallet balance, network connection, and pool liquidity before retrying.'
    );
  }
}

// Cross-platform ES module main detection (handles Windows, symlinks, special characters)
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  runExample().catch(console.error);
}

export { runExample };
