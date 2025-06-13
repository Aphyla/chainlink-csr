/**
 * Example: SlowStake Fee Estimation
 *
 * This example demonstrates how to estimate fees for slowStake operations
 * across all supported L2 chains. SlowStake involves two fee components:
 * 1. CCIP fee for Origin → Ethereum transfer
 * 2. Bridge fee for Ethereum → Origin return transfer
 *
 * The example shows detailed breakdowns for each supported chain with
 * both CCIP fee payment methods (native ETH vs LINK tokens) to help
 * identify the most economical option for each scenario.
 *
 * Usage:
 *   yarn example:lido:estimate-slowstake
 */

import { formatEther } from 'ethers';
import { pathToFileURL } from 'node:url';
import {
  estimateSlowStakeFees,
  type SlowStakeFeeEstimation,
} from '@/useCases/slowStake/estimate';
import {
  getNetworkConfig,
  isProtocolSupportedOnChain,
  LIDO_PROTOCOL,
  TESTING_AMOUNTS,
  SUPPORTED_CHAIN_KEYS,
  type PaymentMethod,
  type CCIPFeePaymentMethod,
} from '@/index';
import type { SupportedChainId } from '@/types';

/**
 * Example demonstrating SlowStake fee estimation using the Lido protocol.
 *
 * Shows detailed fee breakdowns for all supported chains with both
 * CCIP fee payment methods (native ETH vs LINK) and provides cost
 * comparisons to identify the most economical option for each scenario.
 */

/**
 * Run the fee estimation example for a single chain.
 */
async function runSingleEstimation(
  chainKey: SupportedChainId,
  amount: bigint,
  paymentMethod: PaymentMethod,
  ccipFeePaymentMethod: CCIPFeePaymentMethod
): Promise<SlowStakeFeeEstimation> {
  console.log(`\n🔍 Estimating fees for ${getNetworkConfig(chainKey).name}...`);

  const result = await estimateSlowStakeFees({
    chainKey,
    stakingAmount: amount,
    paymentMethod,
    ccipFeePaymentMethod,
    protocol: LIDO_PROTOCOL,
  });

  // Display results
  console.log('✅ Fee estimation completed!\n');

  // Fee breakdown
  console.log('💸 Fee Breakdown:');
  console.log(`  Staking Amount: ${result.summary.stakingAmountFormatted} ETH`);
  console.log(
    `  CCIP Fee (O→D): ${result.summary.feeOtoDFormatted} ${result.summary.feeOtoDToken}`
  );
  console.log(`  Bridge Fee (D→O): ${result.summary.feeDtoOFormatted} ETH`);
  console.log('');
  console.log('💰 Requirements:');
  console.log(`  ETH Required: ${result.summary.ethRequiredFormatted} ETH`);
  if (result.requirements.linkRequired > 0n) {
    console.log(
      `  LINK Required: ${result.summary.linkRequiredFormatted} LINK`
    );
  }
  console.log('');

  // Configuration details
  console.log('⚙️ Configuration:');
  console.log(`  Payment Method: ${result.paymentMethod}`);
  console.log(`  CCIP Fee Payment: ${result.ccipFeePaymentMethod}`);
  console.log(
    `  Gas Limit: ${result.feeOtoD.breakdown.gasLimit.toLocaleString()}`
  );
  console.log('');

  return result;
}

/**
 * Compare fees across multiple supported chains.
 */
async function runMultiChainComparison(
  amount: bigint,
  paymentMethod: PaymentMethod,
  ccipFeePaymentMethod: CCIPFeePaymentMethod
): Promise<void> {
  console.log(
    `\n🌐 Multi-Chain Fee Comparison (CCIP fees in ${ccipFeePaymentMethod.toUpperCase()})`
  );
  console.log('='.repeat(65) + '\n');

  // Dynamically discover all chains that support slowStake
  const supportedChains = SUPPORTED_CHAIN_KEYS.filter(chainKey =>
    isProtocolSupportedOnChain(LIDO_PROTOCOL, chainKey)
  );

  console.log(
    `📋 Testing slowStake on ${supportedChains.length} supported chains:`
  );
  supportedChains.forEach(chainKey => {
    console.log(`  • ${getNetworkConfig(chainKey).name}`);
  });
  console.log('');
  const results: Array<{
    chain: SupportedChainId;
    result: SlowStakeFeeEstimation;
  }> = [];

  for (const chainKey of supportedChains) {
    if (isProtocolSupportedOnChain(LIDO_PROTOCOL, chainKey)) {
      try {
        // Show detailed breakdown for each chain
        const result = await runSingleEstimation(
          chainKey,
          amount,
          paymentMethod,
          ccipFeePaymentMethod
        );
        results.push({ chain: chainKey, result });
      } catch (error) {
        console.error(`❌ Failed to estimate fees for ${chainKey}:`, error);
      }
    }
  }

  // Summary comparison
  if (results.length > 0) {
    console.log('📊 Comparison Summary:');
    const feeToken = results[0]?.result.summary.feeOtoDToken || 'ETH';
    console.log(
      'Chain'.padEnd(15) +
        'ETH Required'.padEnd(20) +
        `CCIP Fee (${feeToken})`.padEnd(20) +
        'Bridge Fee'
    );
    console.log('-'.repeat(75));

    for (const { chain, result } of results) {
      const network = getNetworkConfig(chain);
      console.log(
        network.name.padEnd(15) +
          `${result.summary.ethRequiredFormatted} ETH`.padEnd(20) +
          `${result.summary.feeOtoDFormatted} ${result.summary.feeOtoDToken}`.padEnd(
            20
          ) +
          `${result.summary.feeDtoOFormatted} ETH`
      );
    }
    console.log('');

    // Find most economical option with proper multi-criteria comparison
    const cheapest = results.reduce((min, current) => {
      const currentEth = current.result.requirements.ethRequired;
      const minEth = min.result.requirements.ethRequired;
      const currentLink = current.result.requirements.linkRequired;
      const minLink = min.result.requirements.linkRequired;

      // Primary comparison: ETH requirements
      if (currentEth < minEth) return current;
      if (currentEth > minEth) return min;

      // Secondary comparison: LINK requirements (when ETH is equal)
      if (currentLink < minLink) return current;
      return min;
    });
    console.log(
      `💡 Most economical: ${getNetworkConfig(cheapest.chain).name} (${cheapest.result.summary.ethRequiredFormatted} ETH${cheapest.result.requirements.linkRequired > 0n ? ` + ${cheapest.result.summary.linkRequiredFormatted} LINK` : ''})`
    );
  }
}

/**
 * Main execution function.
 */
async function runExample(): Promise<void> {
  console.log('🔍 SlowStake Fee Estimation Example - Lido Protocol');
  console.log('==================================================\n');

  // Use simple defaults
  const amount = TESTING_AMOUNTS.STANDARD;
  const paymentMethod: PaymentMethod = 'native';

  // Show supported chains
  const supportedChains = SUPPORTED_CHAIN_KEYS.filter(chainKey =>
    isProtocolSupportedOnChain(LIDO_PROTOCOL, chainKey)
  );
  console.log(`🌐 SlowStake is supported on ${supportedChains.length} chains:`);
  supportedChains.forEach(chainKey => {
    console.log(`  • ${getNetworkConfig(chainKey).name}`);
  });
  console.log('');

  // Check if any chains support slowStake
  if (supportedChains.length === 0) {
    throw new Error(
      'No chains support slowStake. Please check the configuration.'
    );
  }

  console.log('📋 Configuration:');
  console.log(`  Protocol: ${LIDO_PROTOCOL.name}`);
  console.log(`  Amount: ${formatEther(amount)} ETH`);
  console.log(`  Payment Method: ${paymentMethod}`);
  console.log('');

  try {
    // Run comparison for both CCIP fee payment methods
    console.log('🔄 Comparing CCIP Fee Payment Methods:\n');

    // 1. Paying CCIP fees with native tokens (ETH)
    console.log('💰 CCIP Fees Paid in Native Tokens (ETH)');
    console.log('='.repeat(50));
    await runMultiChainComparison(amount, paymentMethod, 'native');

    console.log('\n');

    // 2. Paying CCIP fees with LINK tokens
    console.log('🔗 CCIP Fees Paid in LINK Tokens');
    console.log('='.repeat(50));
    await runMultiChainComparison(amount, paymentMethod, 'link');

    console.log('✅ Fee estimation completed successfully!');
  } catch (error) {
    console.error('❌ Fee estimation failed:', error);
    process.exit(1);
  }
}

/**
 * Execute the example when run directly via CLI.
 * Allows safe importing of runExample from other modules without side-effects.
 */
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  runExample().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { runExample };
