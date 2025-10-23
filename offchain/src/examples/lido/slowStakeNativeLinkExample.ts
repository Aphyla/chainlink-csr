import { formatEther, formatUnits } from 'ethers';
import {
  LIDO_PROTOCOL,
  getNetworkConfig,
  createWallet,
  BASE_MAINNET,
  TESTING_AMOUNTS,
} from '@/index';
import { CCIP_EXPLORER_URL } from '@/config/ccip';
import { executeSlowStake } from '@/useCases/slowStake/execute';
import { estimateSlowStakeFees } from '@/useCases/slowStake/estimate';
import { pathToFileURL } from 'node:url';

/**
 * Example: Execute slowStake with native ETH for staking and LINK for CCIP fees.
 * This demonstrates the hybrid flow where:
 * - Staking amount is paid in native ETH (simple, no conversion needed)
 * - CCIP fees are paid in LINK tokens (potentially lower costs)
 * - Bridge fees are paid in native ETH (standard)
 * - Requires LINK token allowance management
 */
async function runExample(): Promise<void> {
  const chainKey = BASE_MAINNET;
  const network = getNetworkConfig(chainKey);

  console.log(`🐌 SlowStake with Native ETH + LINK CCIP on ${network.name}`);
  console.log(`Explorer: ${network.explorer}`);
  console.log('');

  try {
    // Create wallet instance
    const wallet = createWallet(chainKey);
    console.log(`📱 Using wallet: ${wallet.address}`);

    // Transaction parameters
    const stakingAmount = TESTING_AMOUNTS.SMALL; // Use centralized test amount
    const paymentMethod = 'native';
    const ccipFeePaymentMethod = 'link';
    const autoApproveUnlimited = true; // Auto-approve LINK for convenience

    console.log(`💰 Staking amount: ${formatEther(stakingAmount)} ETH`);
    console.log(`💳 Payment method: ${paymentMethod} ETH`);
    console.log(`🔗 CCIP fee payment: LINK tokens`);
    console.log(
      `🔓 Auto-approve unlimited: ${autoApproveUnlimited ? 'Yes' : 'No'}`
    );
    console.log('');

    // Get fee estimation first to show user what's needed
    console.log('📊 Estimating fees...');
    const feeEstimation = await estimateSlowStakeFees({
      chainKey,
      stakingAmount,
      paymentMethod,
      ccipFeePaymentMethod,
      protocol: LIDO_PROTOCOL,
    });

    console.log('✅ Fee estimation completed!');
    console.log('');

    // Display fee breakdown
    console.log('💸 Fee Breakdown:');
    console.log(
      `  Staking Amount: ${feeEstimation.summary.stakingAmountFormatted} ETH`
    );
    console.log(
      `  CCIP Fee (O→D): ${feeEstimation.summary.feeOtoDFormatted} ${feeEstimation.summary.feeOtoDToken}`
    );
    console.log(
      `  Bridge Fee (D→O): ${feeEstimation.summary.feeDtoOFormatted} ETH`
    );
    console.log('');
    console.log('💰 Requirements:');
    console.log(
      `  ETH Required: ${feeEstimation.summary.ethRequiredFormatted} ETH (staking + bridge fees)`
    );
    console.log(
      `  LINK Required: ${feeEstimation.summary.linkRequiredFormatted} LINK (CCIP fees)`
    );
    console.log('');

    // Execute the slowStake transaction
    console.log('🔄 Executing slowStake with native ETH + LINK CCIP...');
    const result = await executeSlowStake({
      chainKey,
      stakingAmount,
      paymentMethod,
      ccipFeePaymentMethod,
      protocol: LIDO_PROTOCOL,
      signer: wallet,
      feeEstimation, // Reuse the estimation
      autoApproveUnlimited,
    });

    // Display comprehensive results
    console.log('');
    console.log('🎉 SlowStake Transaction Successful!');
    console.log('═'.repeat(80));

    // Allowance Management Summary
    console.log('🔐 Allowance Management Summary:');
    console.log('  ETH Allowances:');
    console.log('    ✅ Not Required (using native ETH for staking)');
    console.log('  LINK Allowances:');
    if (result.allowanceManagement.link.checked) {
      console.log(
        `    Token: ${result.allowanceManagement.link.tokenSymbol} (${result.allowanceManagement.link.tokenAddress})`
      );
      console.log(
        `    Initial: ${result.allowanceManagement.link.initialAllowance === 0n ? '0' : formatEther(result.allowanceManagement.link.initialAllowance)} LINK`
      );
      if (result.allowanceManagement.link.approvalNeeded) {
        console.log(
          `    📝 Approval TX: ${result.allowanceManagement.link.approvalTxHash}`
        );
        console.log(
          `    Final: ${result.allowanceManagement.link.finalAllowance.toString() === '115792089237316195423570985008687907853269984665640564039457584007913129639935' ? 'Unlimited (MaxUint256)' : formatEther(result.allowanceManagement.link.finalAllowance)} LINK`
        );
      } else {
        console.log('    ✅ Sufficient Allowance Already Existed');
      }
    }
    console.log('');

    // Transaction Details
    console.log('📊 Transaction Details:');
    console.log(`  TX Hash: ${result.transactionHash}`);
    console.log(`  Message ID: ${result.messageId}`);
    console.log(`  Explorer: ${network.explorer}/tx/${result.transactionHash}`);
    console.log('');

    // SlowStake Event Details
    console.log('📝 SlowStake Event Details:');
    console.log(`  User: ${result.slowStakeEvent.user}`);
    console.log(
      `  Destination Chain: ${result.slowStakeEvent.destChainSelector}`
    );
    console.log(`  Token: ${result.slowStakeEvent.token}`);
    console.log(`  Amount: ${result.slowStakeEvent.formattedAmount} ETH`);
    console.log('');

    // Contract Call Details
    console.log('📋 Contract Call Details:');
    console.log(
      `  Destination Chain: Ethereum (${result.contractCall.destChainSelector})`
    );
    console.log(`  Token: ${result.contractCall.token} (native ETH)`);
    console.log(`  Amount: ${formatEther(result.contractCall.amount)} ETH`);
    console.log(
      `  Total ETH Value: ${formatEther(result.contractCall.totalValue)} ETH (staking + bridge fees)`
    );
    console.log('');

    // Fee Structure Analysis
    console.log('💰 Fee Structure Analysis:');
    console.log(`  Staking Amount: ${formatEther(stakingAmount)} ETH`);
    console.log(
      `  CCIP Fee (O→D): ${result.feeEstimation.summary.feeOtoDFormatted} LINK`
    );
    console.log(
      `    └─ Max Fee: ${formatEther(result.feeEstimation.feeOtoD.breakdown.maxFee)} LINK`
    );
    console.log(
      `    └─ Gas Limit: ${result.feeEstimation.feeOtoD.breakdown.gasLimit.toLocaleString()}`
    );
    console.log(
      `    └─ Pay in LINK: ${result.feeEstimation.feeOtoD.breakdown.payInLink ? 'Yes' : 'No'}`
    );
    console.log(
      `  Bridge Fee (D→O): ${result.feeEstimation.summary.feeDtoOFormatted} ETH`
    );

    // Bridge-specific details
    const bridgeType = result.feeEstimation.feeDtoO.breakdown.bridgeType;
    console.log(`    └─ Bridge Type: ${bridgeType}`);

    if (
      bridgeType === 'arbitrum' &&
      result.feeEstimation.feeDtoO.breakdown.arbitrum
    ) {
      const arb = result.feeEstimation.feeDtoO.breakdown.arbitrum;
      console.log(
        `    └─ Max Submission Cost: ${formatEther(arb.maxSubmissionCost)} ETH`
      );
      console.log(`    └─ Max Gas: ${arb.maxGas.toLocaleString()}`);
      console.log(
        `    └─ Gas Price Bid: ${formatUnits(arb.gasPriceBid, 'gwei')} gwei`
      );
    } else if (
      bridgeType === 'base' &&
      result.feeEstimation.feeDtoO.breakdown.base
    ) {
      const base = result.feeEstimation.feeDtoO.breakdown.base;
      console.log(`    └─ L2 Gas: ${base.l2Gas.toLocaleString()}`);
    } else if (
      bridgeType === 'optimism' &&
      result.feeEstimation.feeDtoO.breakdown.optimism
    ) {
      const op = result.feeEstimation.feeDtoO.breakdown.optimism;
      console.log(`    └─ L2 Gas: ${op.l2Gas.toLocaleString()}`);
    }
    console.log('');

    // Cost Comparison
    console.log('💡 Cost Comparison:');
    console.log('  This Method (Native ETH + LINK):');
    console.log(
      `    ETH: ${formatEther(stakingAmount)} ETH (staking) + ${result.feeEstimation.summary.feeDtoOFormatted} ETH (bridge)`
    );
    console.log(
      `    LINK: ${result.feeEstimation.summary.feeOtoDFormatted} LINK (CCIP fees)`
    );
    console.log(
      '  Alternative (All Native ETH): Would require 0 LINK but higher ETH costs'
    );
    console.log(
      '  Alternative (WETH + LINK): Would require WETH approval and conversion'
    );
    console.log('');

    // Encoded Fee Data (for debugging/verification)
    console.log('🔧 Encoded Fee Data:');
    console.log(`  CCIP Fee Data: ${result.contractCall.feeOtoD}`);
    console.log(`  Bridge Fee Data: ${result.contractCall.feeDtoO}`);
    console.log('');

    // Contract Information
    console.log('📋 Contract Information:');
    console.log(
      `  CustomSender: ${result.feeEstimation.contracts.customSender}`
    );
    console.log(`  CCIP Router: ${result.feeEstimation.contracts.ccipRouter}`);
    console.log(`  WETH Token: ${result.feeEstimation.contracts.wnative}`);
    console.log(`  LINK Token: ${result.feeEstimation.contracts.linkToken}`);
    console.log('');

    // Next Steps Information
    console.log('🔮 What Happens Next:');
    console.log(
      '  1. 🌉 Your ETH will be bridged to Ethereum via CCIP (paid with LINK)'
    );
    console.log(
      '  2. 🏛️ On Ethereum, ETH will be staked with Lido to get stETH'
    );
    console.log(
      '  3. 🔄 stETH will be wrapped to wstETH for yield optimization'
    );
    console.log('  4. 🚀 wstETH will be bridged back to you on this chain');
    console.log(
      '  5. ⏰ Total process takes ~50 minutes for complete round-trip'
    );
    console.log('');

    // Tracking Instructions
    console.log('📍 How to Track Your Cross-Chain Transaction:');
    console.log('');
    console.log('🔗 Step 1: Track CCIP Message (Origin → Destination)');
    console.log(`   Monitor: ${CCIP_EXPLORER_URL}/msg/${result.messageId}`);
    console.log('   Wait for status to show "Success" (usually 10-20 minutes)');
    console.log('   This confirms your ETH reached Ethereum and was staked');
    console.log('');
    console.log('🏛️ Step 2: Verify Ethereum Execution');
    console.log(
      '   Once CCIP shows "Success", click "View on Destination Chain"'
    );
    console.log(
      '   Look for "BaseL1toL2MessageSent" event in the transaction logs'
    );
    console.log(
      '   This confirms wstETH bridging back to your origin chain started'
    );
    console.log('');
    console.log('🔄 Step 3: Wait for Return Bridge (Destination → Origin)');
    console.log('   The canonical bridge will deliver wstETH back to you');
    console.log('   This usually takes 30-40 additional minutes');
    console.log('   No action needed - the bridge handles this automatically');
    console.log('');
    console.log('🎯 Quick Links:');
    console.log(
      `   Origin TX: ${network.explorer}/tx/${result.transactionHash}`
    );
    console.log(
      `   CCIP Tracker: ${CCIP_EXPLORER_URL}/msg/${result.messageId}`
    );
    console.log(`   Message ID: ${result.messageId}`);
  } catch (error) {
    console.error('❌ SlowStake execution failed:');
    console.error('');
    console.error('🔍 Error Details:');
    console.error(error);
    console.error('');
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
