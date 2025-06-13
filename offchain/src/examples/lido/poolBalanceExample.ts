import {
  getPoolBalances,
  LIDO_PROTOCOL,
  getNetworkConfig,
  SUPPORTED_CHAIN_KEYS,
  isProtocolSupportedOnChain,
} from '@/index';
import { pathToFileURL } from 'node:url';

/**
 * Example: Query pool balances for TOKEN_IN and TOKEN_OUT on different chains.
 * This demonstrates how to check pool liquidity without performing estimations.
 */
async function runPoolBalanceExample(): Promise<void> {
  console.log('🏊 Lido Pool Balance Query');
  console.log('═'.repeat(60));
  console.log('');

  // Filter to only chains where Lido protocol is actually deployed
  const supportedChains = SUPPORTED_CHAIN_KEYS.filter(chainKey =>
    isProtocolSupportedOnChain(LIDO_PROTOCOL, chainKey)
  );

  console.log(
    `🔍 Found ${supportedChains.length} chains with Lido protocol support`
  );
  console.log('');

  // Type-safe iteration over supported chains only
  for (const chainKey of supportedChains) {
    try {
      const network = getNetworkConfig(chainKey);
      console.log(`🔍 Checking ${network.name} (Chain ID: ${network.chainId})`);
      console.log(`Explorer: ${network.explorer}`);
      console.log('');

      const result = await getPoolBalances({
        chainKey,
        protocol: LIDO_PROTOCOL,
      });

      // Contract information
      console.log(`📋 Contract Info:`);
      console.log(`  Pool Address: ${result.poolAddress}`);
      console.log(`  Sender Address: ${result.senderAddress}`);
      console.log('');

      // TOKEN_IN (usually WETH)
      console.log(`💰 ${result.tokenIn.symbol} (${result.tokenIn.name}):`);
      console.log(`  Address: ${result.tokenIn.address}`);
      console.log(
        `  Balance: ${result.tokenIn.formattedBalance} ${result.tokenIn.symbol}`
      );
      console.log(`  Decimals: ${result.tokenIn.decimals}`);
      console.log('');

      // TOKEN_OUT (usually wstETH)
      console.log(`🪙 ${result.tokenOut.symbol} (${result.tokenOut.name}):`);
      console.log(`  Address: ${result.tokenOut.address}`);
      console.log(
        `  Balance: ${result.tokenOut.formattedBalance} ${result.tokenOut.symbol}`
      );
      console.log(`  Decimals: ${result.tokenOut.decimals}`);
      console.log('');

      // Pool composition
      console.log(`📊 Pool Composition:`);
      console.log(
        `  Balance Ratio: ${result.balanceRatio} ${result.tokenOut.symbol}/${result.tokenIn.symbol}`
      );

      // Liquidity assessment
      const tokenInBalance = Number(result.tokenIn.formattedBalance);
      const tokenOutBalance = Number(result.tokenOut.formattedBalance);

      if (tokenInBalance === 0 && tokenOutBalance === 0) {
        console.log(`  Status: 🚫 Pool appears empty`);
      } else if (tokenOutBalance < 1) {
        console.log(
          `  Status: ⚠️  Low TOKEN_OUT liquidity (${result.tokenOut.symbol})`
        );
      } else if (tokenInBalance > 100) {
        console.log(`  Status: 💰 High TOKEN_IN accumulation (needs sync)`);
      } else {
        console.log(`  Status: ✅ Pool appears healthy`);
      }
    } catch (error) {
      console.error(`❌ Error querying ${chainKey}:`);
      console.error(`   ${error instanceof Error ? error.message : error}`);
    }

    console.log('═'.repeat(60));
    console.log('');
  }

  console.log(`💡 Understanding Pool Balances:`);
  console.log(`   • TOKEN_IN (WETH): Accumulates from user fast stakes`);
  console.log(`   • TOKEN_OUT (wstETH): Available for immediate swaps`);
  console.log(`   • High TOKEN_IN balance indicates need for sync operation`);
  console.log(`   • Low TOKEN_OUT balance may cause fast stake failures`);
  console.log('');
  console.log(
    `🔄 The sync operation moves TOKEN_IN to L1 for staking and refills TOKEN_OUT`
  );
}

// Cross-platform ES module main detection (handles Windows, symlinks, special characters)
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  runPoolBalanceExample().catch(console.error);
}

export { runPoolBalanceExample };
