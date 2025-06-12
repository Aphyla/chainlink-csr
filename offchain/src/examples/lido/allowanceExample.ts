import { formatUnits } from 'ethers';
import {
  checkTokenAllowance,
  LIDO_PROTOCOL,
  getNetworkConfig,
  ARBITRUM_ONE,
  OPTIMISM_MAINNET,
  BASE_MAINNET,
  createWallet,
} from '@/index';
import { pathToFileURL } from 'node:url';
import type { SupportedChainId } from '@/types';

/**
 * Example: Check TOKEN allowances for Lido protocol across all supported chains.
 * This demonstrates how to use the checkTokenAllowance function and
 * shows allowance status, token information, and helpful guidance.
 */
async function runExample(): Promise<void> {
  // User address - leave empty to use current signer, or provide specific address
  let userAddress = ''; // Override this with your specific address if needed

  // If no user address provided, try to get it from the current signer
  if (!userAddress) {
    try {
      // Use the first supported chain to create a wallet and get the signer address
      const wallet = createWallet(BASE_MAINNET);
      userAddress = wallet.address;
      console.log(`📱 Using current signer address: ${userAddress}`);
    } catch (error) {
      console.error('❌ No user address provided and no wallet configured.');
      console.error(
        '💡 Set PRIVATE_KEY environment variable or provide userAddress manually.'
      );
      console.error(
        `   Error: ${error instanceof Error ? error.message : error}`
      );
      return;
    }
  } else {
    console.log(`📱 Using provided address: ${userAddress}`);
  }

  console.log(`🔍 Checking Lido TOKEN Allowances for User: ${userAddress}`);
  console.log('');

  // All supported chains for Lido
  const supportedChains: SupportedChainId[] = [
    ARBITRUM_ONE,
    OPTIMISM_MAINNET,
    BASE_MAINNET,
  ];

  // Check allowances across all chains
  for (const chainKey of supportedChains) {
    const network = getNetworkConfig(chainKey);

    try {
      console.log(`🌐 ${network.name} (Chain ID: ${network.chainId})`);
      console.log(`Explorer: ${network.explorer}`);

      const result = await checkTokenAllowance({
        chainKey,
        userAddress,
        protocol: LIDO_PROTOCOL,
      });

      // Token Information
      console.log(`🪙 TOKEN Information:`);
      console.log(
        `  Token: ${result.allowanceInfo.token.symbol} (${result.allowanceInfo.token.name})`
      );
      console.log(`  Address: ${result.allowanceInfo.token.address}`);
      console.log(`  Decimals: ${result.allowanceInfo.token.decimals}`);
      console.log('');

      // Contract Information
      console.log(`📋 Contract Addresses:`);
      console.log(`  CustomSender: ${result.contracts.customSender}`);
      console.log(`  OraclePool: ${result.contracts.oraclePool}`);
      console.log(`  WNATIVE: ${result.contracts.wnative}`);
      console.log('');

      // User Balance
      const userBalanceFormatted = formatUnits(
        result.allowanceInfo.userBalance,
        result.allowanceInfo.token.decimals
      );
      console.log(`💰 User Balance:`);
      console.log(
        `  ${userBalanceFormatted} ${result.allowanceInfo.token.symbol}`
      );
      console.log('');

      // Allowance Status
      console.log(`🔐 Allowance Status:`);

      if (result.allowanceInfo.hasUnlimitedAllowance) {
        console.log(`  ✅ UNLIMITED ALLOWANCE`);
        console.log(
          `  User has approved unlimited ${result.allowanceInfo.token.symbol} to CustomSender`
        );
      } else if (result.allowanceInfo.hasAllowance) {
        const allowanceFormatted = formatUnits(
          result.allowanceInfo.allowance,
          result.allowanceInfo.token.decimals
        );
        console.log(`  ⚠️  LIMITED ALLOWANCE`);
        console.log(
          `  Current allowance: ${allowanceFormatted} ${result.allowanceInfo.token.symbol}`
        );

        // Check if allowance is sufficient for user's balance
        if (
          result.allowanceInfo.allowance >= result.allowanceInfo.userBalance
        ) {
          console.log(`  ✅ Allowance covers full user balance`);
        } else {
          console.log(`  ❌ Allowance is less than user balance`);
          const shortfall =
            result.allowanceInfo.userBalance - result.allowanceInfo.allowance;
          const shortfallFormatted = formatUnits(
            shortfall,
            result.allowanceInfo.token.decimals
          );
          console.log(
            `  Shortfall: ${shortfallFormatted} ${result.allowanceInfo.token.symbol}`
          );
        }
      } else {
        console.log(`  ❌ NO ALLOWANCE`);
        console.log(
          `  User must approve ${result.allowanceInfo.token.symbol} to use fastStakeReferral`
        );
      }
      console.log('');

      // Action Required
      console.log(`🎯 Required Actions:`);

      if (result.allowanceInfo.userBalance === 0n) {
        console.log(
          `  💸 Get ${result.allowanceInfo.token.symbol} tokens first`
        );
      } else if (!result.allowanceInfo.hasAllowance) {
        console.log(
          `  📝 Approve ${result.allowanceInfo.token.symbol} allowance to CustomSender`
        );
        console.log(
          `  Example: await tokenContract.approve("${result.contracts.customSender}", amount)`
        );
      } else if (
        !result.allowanceInfo.hasUnlimitedAllowance &&
        result.allowanceInfo.allowance < result.allowanceInfo.userBalance
      ) {
        console.log(
          `  📝 Increase ${result.allowanceInfo.token.symbol} allowance for full balance usage`
        );
        console.log(`  Current allowance only covers partial balance`);
      } else {
        console.log(`  ✅ Ready for fastStakeReferral operations!`);
        console.log(`  User can stake up to their current allowance/balance`);
      }
      console.log('');

      // Usage Example
      console.log(`💡 Usage Example:`);
      console.log(`  // For ${network.name}:`);
      console.log(`  await customSender.fastStakeReferral(`);
      console.log(
        `    "${result.allowanceInfo.token.address}", // TOKEN address`
      );
      console.log(
        `    parseEther("1.0"), // 1 ${result.allowanceInfo.token.symbol}`
      );
      console.log(`    minAmountOut, // Minimum output amount`);
      console.log(`    referralAddress // Referral address`);
      console.log(`  );`);
    } catch (error) {
      console.error(
        `  ❌ Error checking allowance: ${error instanceof Error ? error.message : error}`
      );
    }

    console.log('═'.repeat(80));
    console.log('');
  }

  // Summary and Educational Content
  console.log(`📚 Understanding TOKEN Allowances:`);
  console.log('');
  console.log(`🔍 What is TOKEN?`);
  console.log(
    `   TOKEN is the immutable address stored in CustomSender contract`
  );
  console.log(
    `   It represents the token users send for staking (usually WETH)`
  );
  console.log(`   Retrieved via: await customSender.TOKEN()`);
  console.log('');
  console.log(`🔐 Why Check Allowances?`);
  console.log(
    `   fastStakeReferral() needs to transfer TOKEN from user to contract`
  );
  console.log(`   ERC20 tokens require explicit approval before transfers`);
  console.log(
    `   This is different from native ETH (address(0)) which doesn't need approval`
  );
  console.log('');
  console.log(`📝 Approval Options:`);
  console.log(`   1. Exact Amount: approve(spender, exactAmount)`);
  console.log(
    `   2. Unlimited: approve(spender, MaxUint256) // Most convenient`
  );
  console.log(
    `   3. Per Transaction: approve before each fastStakeReferral call`
  );
  console.log('');
  console.log(`⚡ Fast Stake Flow:`);
  console.log(`   1. User approves TOKEN to CustomSender (if using WETH)`);
  console.log(`   2. Call fastStakeReferral() with TOKEN address and amount`);
  console.log(
    `   3. OR call with address(0) and send native ETH (no approval needed)`
  );
  console.log('');
  console.log(`🔗 Alternative: Use Native ETH`);
  console.log(`   await customSender.fastStakeReferral(`);
  console.log(
    `     "0x0000000000000000000000000000000000000000", // address(0)`
  );
  console.log(`     parseEther("1.0"),`);
  console.log(`     minAmountOut,`);
  console.log(`     referralAddress,`);
  console.log(`     { value: parseEther("1.0") } // Send ETH directly`);
  console.log(`   );`);
}

// Cross-platform ES module main detection (handles Windows, symlinks, special characters)
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  runExample().catch(console.error);
}

export { runExample };
