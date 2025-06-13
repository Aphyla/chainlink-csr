import { parseEther, formatEther, formatUnits } from 'ethers';
import {
  estimateFastStake,
  LIDO_PROTOCOL,
  getNetworkConfig,
  BASE_MAINNET,
} from '@/index';
import { pathToFileURL } from 'node:url';

/**
 * Example: Estimate fast stake for different amounts on Arbitrum.
 * This demonstrates how to use the estimateFastStakeLido function and
 * shows detailed breakdown of fees, pricing, and liquidity.
 */
async function runExample(): Promise<void> {
  const chainKey = BASE_MAINNET;
  const network = getNetworkConfig(chainKey);

  console.log(`🔍 Testing Lido Fast Stake Estimation on ${network.name}`);
  console.log(`Explorer: ${network.explorer}`);
  console.log('');

  // Test different amounts
  const testAmounts = ['0.1', '1.0', '5.0'];

  for (const amountStr of testAmounts) {
    const amountIn = parseEther(amountStr);

    try {
      console.log(`💰 Estimating ${amountStr} WETH...`);

      const result = await estimateFastStake({
        chainKey,
        amountIn,
        protocol: LIDO_PROTOCOL,
      });

      // Contract Information
      console.log(`📋 Contract Details:`);
      console.log(`  CustomSender: ${result.contracts.customSender}`);
      console.log(`  OraclePool: ${result.contracts.oraclePool}`);
      console.log(`  PriceOracle: ${result.contracts.priceOracle}`);
      console.log(`  WNATIVE: ${result.contracts.wnative}`);
      console.log(`  LINK Token: ${result.contracts.linkToken}`);
      console.log('');

      // Token Information
      console.log(`🪙 Tokens:`);
      console.log(
        `  TOKEN_IN:  ${result.contracts.tokenIn.symbol} (${result.contracts.tokenIn.name})`
      );
      console.log(`             ${result.contracts.tokenIn.address}`);
      console.log(
        `             Decimals: ${result.contracts.tokenIn.decimals}`
      );
      console.log(
        `  TOKEN_OUT: ${result.contracts.tokenOut.symbol} (${result.contracts.tokenOut.name})`
      );
      console.log(`             ${result.contracts.tokenOut.address}`);
      console.log(
        `             Decimals: ${result.contracts.tokenOut.decimals}`
      );
      console.log('');

      // Fee Breakdown
      const feePercentage =
        Number((result.fees.feeRate * 10000n) / 10n ** 18n) / 100;
      console.log(`💸 Fee Analysis:`);
      console.log(`  Fee Rate: ${feePercentage}%`);
      console.log(
        `  Fee Amount: ${formatEther(result.fees.feeAmount)} ${
          result.contracts.tokenIn.symbol
        }`
      );
      console.log(
        `  Amount After Fee: ${formatEther(result.fees.amountAfterFee)} ${
          result.contracts.tokenIn.symbol
        }`
      );
      console.log('');

      // Pricing Information
      console.log(`📈 Pricing:`);
      console.log(
        `  Oracle Price: ${formatEther(result.pricing.price)} (${result.contracts.tokenIn.symbol} per ${result.contracts.tokenOut.symbol})`
      );
      console.log(`  Is Inverse: ${result.pricing.isInverse}`);
      console.log(`  Heartbeat: ${result.pricing.heartbeat} seconds`);
      console.log(
        `  Effective Rate: ${formatEther(result.effectiveRate)} ${
          result.contracts.tokenOut.symbol
        }/${result.contracts.tokenIn.symbol}`
      );
      console.log('');

      // Pool Liquidity
      const availableFormatted = formatUnits(
        result.pool.availableOut,
        result.contracts.tokenOut.decimals
      );
      console.log(`🏊 Pool Liquidity:`);
      console.log(
        `  Available ${result.contracts.tokenOut.symbol}: ${availableFormatted}`
      );
      console.log(
        `  Sufficient Liquidity: ${
          result.pool.hasSufficientLiquidity ? '✅ Yes' : '❌ No'
        }`
      );
      console.log(`  Pool Sender: ${result.pool.poolSender}`);
      console.log('');

      // Final Results
      const amountOutFormatted = formatUnits(
        result.amountOut,
        result.contracts.tokenOut.decimals
      );
      console.log(`🎯 Expected Output:`);
      console.log(
        `  You'll receive: ${amountOutFormatted} ${result.contracts.tokenOut.symbol}`
      );

      if (!result.pool.hasSufficientLiquidity) {
        console.log(
          `  ⚠️  WARNING: Insufficient pool liquidity! Transaction will fail.`
        );
        console.log(
          `     Need: ${amountOutFormatted} ${result.contracts.tokenOut.symbol}`
        );
        console.log(
          `     Available: ${availableFormatted} ${result.contracts.tokenOut.symbol}`
        );
      }
    } catch (error) {
      console.error(
        `  ❌ Error: ${error instanceof Error ? error.message : error}`
      );
    }

    console.log('═'.repeat(80));
    console.log('');
  }

  console.log(`💡 Understanding the Calculation:`);
  console.log(
    `   1. Fee Deduction: amountAfterFee = amountIn - (amountIn * feeRate / 1e18)`
  );
  console.log(
    `   2. Price Conversion: amountOut = amountAfterFee * 1e18 / oraclePrice`
  );
  console.log(`   3. Liquidity Check: amountOut <= availableBalance`);
  console.log('');
  console.log(
    `🔗 The oracle price represents the cost in TOKEN_IN to buy 1 TOKEN_OUT.`
  );
  console.log(
    `   For Lido: How much WETH it costs to buy 1 wstETH (currently ~1.205 WETH)`
  );
  console.log(
    `   Therefore: 1 WETH buys 1/oraclePrice wstETH (currently ~0.829 wstETH)`
  );
}

// Cross-platform ES module main detection (handles Windows, symlinks, special characters)
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  runExample().catch(console.error);
}

export { runExample };
