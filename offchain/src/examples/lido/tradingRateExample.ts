import {
  getTradingRate,
  LIDO_PROTOCOL,
  getNetworkConfig,
  SUPPORTED_CHAIN_KEYS,
} from '@/index';
import { formatHeartbeat } from '@/core/oracle/pricing';
import { pathToFileURL } from 'node:url';

/**
 * Example: Get the actual trading rates users would receive for fast staking.
 * This shows oracle prices, fees, and effective exchange rates.
 */
async function runTradingRateExample(): Promise<void> {
  console.log('💱 Lido Trading Rate Query');
  console.log('═'.repeat(60));
  console.log('');

  // Type-safe iteration over all supported chains
  for (const chainKey of SUPPORTED_CHAIN_KEYS) {
    try {
      const network = getNetworkConfig(chainKey);
      console.log(`🔍 Checking ${network.name} (Chain ID: ${network.chainId})`);
      console.log(`Explorer: ${network.explorer}`);
      console.log('');

      const result = await getTradingRate({
        chainKey,
        protocol: LIDO_PROTOCOL,
      });

      // Contract information
      console.log(`📋 Contract Info:`);
      console.log(`  Pool: ${result.poolAddress}`);
      console.log(`  Sender: ${result.senderAddress}`);
      console.log(`  Oracle: ${result.oracleAddress}`);
      console.log('');

      // Trading pair
      console.log(
        `🔄 Trading Pair: ${result.tokenIn.symbol} → ${result.tokenOut.symbol}`
      );
      console.log('');

      // Oracle information
      console.log(`🔮 Oracle Information:`);
      console.log(
        `  Current Price: ${result.oracle.formattedPrice} ${result.tokenOut.symbol}/${result.tokenIn.symbol}`
      );
      console.log(
        `  Heartbeat: ${result.oracle.heartbeat} seconds (${formatHeartbeat(result.oracle.heartbeat)})`
      );
      console.log(`  Is Inverted: ${result.oracle.inverted ? 'Yes' : 'No'}`);
      console.log(`  Decimals: ${result.oracle.decimals}`);
      console.log('');

      // Fee information
      console.log(`💰 Fee Information:`);
      console.log(`  Fee Rate: ${result.fee.percentage}`);
      console.log(`  Fee (raw): ${result.fee.rate} (1e18 scale)`);
      console.log('');

      // Exchange rates
      console.log(`📊 Exchange Rates:`);
      console.log(`  Oracle Rate: ${result.rate.oracleRate}`);
      console.log(`  Effective Rate: ${result.rate.effectiveRate}`);
      console.log(`  Impact: ${result.rate.description}`);
      console.log('');

      // Calculate example amounts (1 TOKEN_IN input)
      const inputAmount = 1; // 1 TOKEN_IN
      const oracleRateNum = Number(result.oracle.formattedPrice);
      const feeRateNum = Number(result.fee.rate) / 1e18;

      // Fee is applied to TOKEN_IN (as per OraclePool.sol logic)
      const feeAmountInTokenIn = inputAmount * feeRateNum;
      const amountAfterFee = inputAmount - feeAmountInTokenIn;
      const finalOutput = amountAfterFee * oracleRateNum;

      console.log(`📖 Example (1 ${result.tokenIn.symbol}):`);
      console.log(
        `  Input: ${inputAmount.toFixed(6)} ${result.tokenIn.symbol}`
      );
      console.log(
        `  Fee: ${feeAmountInTokenIn.toFixed(6)} ${result.tokenIn.symbol} (${(feeRateNum * 100).toFixed(2)}%)`
      );
      console.log(
        `  After fee: ${amountAfterFee.toFixed(6)} ${result.tokenIn.symbol}`
      );
      console.log(
        `  Final output: ${finalOutput.toFixed(6)} ${result.tokenOut.symbol}`
      );
    } catch (error) {
      console.error(`❌ Error querying ${chainKey}:`);
      console.error(`   ${error instanceof Error ? error.message : error}`);
    }

    console.log('═'.repeat(60));
    console.log('');
  }

  console.log(`💡 Understanding Trading Rates:`);
  console.log(`   • Oracle Rate: Market price from price oracle`);
  console.log(`   • Pool Fee: Small percentage taken by the pool`);
  console.log(`   • Effective Rate: What you actually receive after fees`);
  console.log(`   • Heartbeat: How often oracle updates (freshness)`);
  console.log('');
  console.log(`🔄 This rate applies to fast staking operations only`);
  console.log(`💰 Slow staking bypasses pool and has different rates`);
}

// Cross-platform ES module main detection (handles Windows, symlinks, special characters)
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  runTradingRateExample().catch(console.error);
}

export { runTradingRateExample };
