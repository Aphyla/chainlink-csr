# Pool API Reference

Pool monitoring and trading rate analysis for liquid staking operations. These functions provide insights into pool liquidity, exchange rates, and market conditions.

## Overview

Pool operations provide essential market data:

1. **Pool Balances** - Monitor token liquidity in oracle pools
2. **Trading Rates** - Get current exchange rates and fee information
3. **Market Analysis** - Assess pool health and optimal transaction timing

These functions help determine whether to use fast stake (pool-based) or slow stake (cross-chain) approaches.

## Functions

- [`getPoolBalances()`](#getpoolbalances) - Query current pool token balances and liquidity
- [`getTradingRate()`](#gettradingrate) - Get current exchange rates, fees, and market data

---

## `getPoolBalances()`

Retrieves current token balances in the oracle pool, providing a snapshot of available liquidity for fast stake operations.

### Function Signature

```typescript
function getPoolBalances(params: PoolBalanceParams): Promise<PoolBalanceResult>;
```

### Parameters

```typescript
interface PoolBalanceParams {
  /** Supported chain key for operations */
  chainKey: SupportedChainId;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
}
```

### Returns

```typescript
interface PoolBalanceResult {
  /** OraclePool contract address */
  readonly poolAddress: Address;
  /** CustomSender contract address */
  readonly senderAddress: Address;
  /** TOKEN_IN balance and metadata (usually WETH) */
  readonly tokenIn: TokenBalance;
  /** TOKEN_OUT balance and metadata (usually wstETH) */
  readonly tokenOut: TokenBalance;
  /** Total value ratio: tokenOut.balance / tokenIn.balance */
  readonly balanceRatio: string;
}
```

#### Return Type Details

```typescript
interface TokenBalance {
  /** Token contract information */
  readonly token: TokenInfo;
  /** Token balance in the pool, in wei */
  readonly balance: bigint;
  /** Formatted balance for display */
  readonly formattedBalance: string;
}

interface TokenInfo {
  readonly address: Address;
  readonly symbol: string; // e.g., 'WETH', 'wstETH'
  readonly name: string; // e.g., 'Wrapped Ether'
  readonly decimals: number; // Usually 18
}
```

### Usage Example

```typescript
import { getPoolBalances, LIDO_PROTOCOL } from '@chainlink/csr-offchain';
import { formatEther } from 'ethers';

const poolInfo = await getPoolBalances({
  chainKey: 'BASE_MAINNET',
  protocol: LIDO_PROTOCOL,
});

console.log(`Pool Address: ${poolInfo.poolAddress}`);
console.log(`TOKEN_IN (${poolInfo.tokenIn.token.symbol}): ${poolInfo.tokenIn.formattedBalance}`);
console.log(`TOKEN_OUT (${poolInfo.tokenOut.token.symbol}): ${poolInfo.tokenOut.formattedBalance}`);
console.log(`Balance Ratio: ${poolInfo.balanceRatio}`);

// Check if pool has sufficient liquidity for a transaction
const requiredOut = parseEther('1.0');
if (poolInfo.tokenOut.balance >= requiredOut) {
  console.log('✅ Sufficient liquidity for fast stake');
} else {
  console.log('❌ Insufficient liquidity - consider slow stake');
}
```

### Liquidity Assessment

```typescript
function assessPoolLiquidity(poolInfo: PoolBalanceResult) {
  const { tokenIn, tokenOut } = poolInfo;

  // Convert to numbers for analysis
  const inBalance = Number(formatEther(tokenIn.balance));
  const outBalance = Number(formatEther(tokenOut.balance));
  const ratio = Number(poolInfo.balanceRatio);

  // Analysis thresholds (example values)
  const thresholds = {
    lowLiquidity: 1.0, // Less than 1 token
    healthyRatio: 50.0, // Balanced pool state
    imbalancedRatio: 200.0, // Pool needs rebalancing
  };

  const assessment = {
    inLiquidityStatus: inBalance > thresholds.lowLiquidity ? 'Healthy' : 'Low',
    outLiquidityStatus: outBalance > thresholds.lowLiquidity ? 'Healthy' : 'Low',
    ratioStatus:
      ratio > thresholds.imbalancedRatio
        ? 'Imbalanced'
        : ratio > thresholds.healthyRatio
          ? 'Healthy'
          : 'Needs sync',
    overallHealth: 'Good', // Simplified logic
  };

  return assessment;
}

const assessment = assessPoolLiquidity(poolInfo);
console.log(`Pool Health: ${assessment.overallHealth}`);
```

### Multi-Chain Pool Monitoring

```typescript
import { SUPPORTED_CHAINS } from '@chainlink/csr-offchain';

async function monitorPoolsAcrossChains() {
  const poolData = await Promise.allSettled(
    SUPPORTED_CHAINS.map(async chainKey => {
      const poolInfo = await getPoolBalances({
        chainKey,
        protocol: LIDO_PROTOCOL,
      });
      return { chainKey, poolInfo };
    })
  );

  poolData.forEach((result, index) => {
    const chainKey = SUPPORTED_CHAINS[index];

    if (result.status === 'fulfilled') {
      const { poolInfo } = result.value;
      console.log(`${chainKey}:`);
      console.log(`  ${poolInfo.tokenIn.token.symbol}: ${poolInfo.tokenIn.formattedBalance}`);
      console.log(`  ${poolInfo.tokenOut.token.symbol}: ${poolInfo.tokenOut.formattedBalance}`);
      console.log(`  Ratio: ${poolInfo.balanceRatio}`);
    } else {
      console.log(`${chainKey}: Error - ${result.reason.message}`);
    }
  });
}
```

### Errors

| Error                               | When                      | Resolution                |
| ----------------------------------- | ------------------------- | ------------------------- |
| `Protocol not supported on {chain}` | Invalid chainKey/protocol | Use supported combination |
| `Pool contract not found`           | Deployment issues         | Verify contract addresses |
| `Token balance fetch failed`        | RPC connectivity          | Check RPC endpoints       |

---

## `getTradingRate()`

Retrieves current trading rates, fees, and market conditions for fast stake operations. Provides comprehensive pricing information from oracle data.

### Function Signature

```typescript
function getTradingRate(params: TradingRateParams): Promise<TradingRateResult>;
```

### Parameters

```typescript
interface TradingRateParams {
  /** Supported chain key for operations */
  chainKey: SupportedChainId;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
}
```

### Returns

```typescript
interface TradingRateResult {
  /** OraclePool contract address */
  readonly poolAddress: Address;
  /** CustomSender contract address */
  readonly senderAddress: Address;
  /** PriceOracle contract address */
  readonly oracleAddress: Address;
  /** TOKEN_IN information */
  readonly tokenIn: TokenInfo;
  /** TOKEN_OUT information */
  readonly tokenOut: TokenInfo;
  /** Oracle pricing details */
  readonly oracle: OraclePricing;
  /** Pool fee information */
  readonly fee: FeeInfo;
  /** Effective exchange rates */
  readonly rate: EffectiveRate;
}
```

#### Return Type Details

```typescript
interface OraclePricing {
  /** Current oracle price (TOKEN_IN per TOKEN_OUT, scaled by 1e18) */
  readonly price: bigint;
  /** Formatted oracle price */
  readonly formattedPrice: string;
  /** Oracle heartbeat in seconds (how often it updates) */
  readonly heartbeat: bigint;
  /** Oracle output decimals (should be 18 for PriceOracle) */
  readonly decimals: number;
}

interface FeeInfo {
  /** Fee rate (scaled by 1e18) */
  readonly rate: bigint;
  /** Fee percentage (human readable) */
  readonly percentage: string;
}

interface EffectiveRate {
  /** Oracle rate showing cost (1 TOKEN_OUT = X TOKEN_IN) */
  readonly oracleRate: string;
  /** Effective rate showing what you receive (1 TOKEN_IN = X TOKEN_OUT) */
  readonly effectiveRate: string;
  /** Rate description */
  readonly description: string;
}
```

### Usage Example

```typescript
import { getTradingRate, LIDO_PROTOCOL } from '@chainlink/csr-offchain';

const rateInfo = await getTradingRate({
  chainKey: 'BASE_MAINNET',
  protocol: LIDO_PROTOCOL,
});

console.log('=== Trading Rate Information ===');
console.log(
  `Oracle Price: ${rateInfo.oracle.formattedPrice} ${rateInfo.tokenIn.symbol} per ${rateInfo.tokenOut.symbol}`
);
console.log(`Pool Fee: ${rateInfo.fee.percentage}`);
console.log(`Oracle Rate: ${rateInfo.rate.oracleRate}`);
console.log(`Effective Rate: ${rateInfo.rate.effectiveRate}`);
console.log(`Description: ${rateInfo.rate.description}`);

// Oracle health check
const maxHeartbeat = 24 * 60 * 60; // 24 hours
if (Number(rateInfo.oracle.heartbeat) > maxHeartbeat) {
  console.warn('⚠️ Oracle heartbeat exceeds 24 hours');
} else {
  console.log(`✅ Oracle heartbeat: ${rateInfo.oracle.heartbeat} seconds`);
}
```

### Rate Comparison and Analysis

```typescript
function analyzeRates(rateInfo: TradingRateResult) {
  const { oracle, fee, rate } = rateInfo;

  // Extract numeric values for analysis
  const oraclePrice = Number(oracle.formattedPrice);
  const feeRate = Number(fee.rate) / 1e18; // Convert from wei to percentage
  const effectiveRateMatch = rate.effectiveRate.match(/1 \w+ = ([\d.]+)/);
  const effectiveRate = effectiveRateMatch ? Number(effectiveRateMatch[1]) : 0;

  // Calculate fee impact
  const expectedWithoutFee = 1 / oraclePrice;
  const feeImpact = ((expectedWithoutFee - effectiveRate) / expectedWithoutFee) * 100;

  return {
    oraclePrice,
    effectiveRate,
    feePercentage: feeRate * 100,
    feeImpact: feeImpact.toFixed(4),
    priceDeviation: 'N/A', // Would need historical data
  };
}

const analysis = analyzeRates(rateInfo);
console.log(`Fee Impact: ${analysis.feeImpact}%`);
console.log(
  `Effective vs Oracle: ${((analysis.effectiveRate / (1 / analysis.oraclePrice)) * 100).toFixed(2)}%`
);
```

### Historical Rate Tracking

```typescript
// Rate monitoring pattern for DeFi applications
class RateMonitor {
  private rateHistory: Array<{ timestamp: number; rate: TradingRateResult }> = [];

  async updateRate(chainKey: SupportedChainId, protocol: ProtocolConfig) {
    try {
      const rate = await getTradingRate({ chainKey, protocol });
      this.rateHistory.push({
        timestamp: Date.now(),
        rate,
      });

      // Keep only last 24 hours
      const cutoff = Date.now() - 24 * 60 * 60 * 1000;
      this.rateHistory = this.rateHistory.filter(entry => entry.timestamp > cutoff);

      return rate;
    } catch (error) {
      console.error('Rate update failed:', error);
      throw error;
    }
  }

  getLatestRate() {
    return this.rateHistory[this.rateHistory.length - 1]?.rate;
  }

  calculateRateChange(hours: number = 1) {
    if (this.rateHistory.length < 2) return null;

    const now = Date.now();
    const cutoff = now - hours * 60 * 60 * 1000;
    const earlierRate = this.rateHistory.find(entry => entry.timestamp <= cutoff);
    const latestRate = this.getLatestRate();

    if (!earlierRate || !latestRate) return null;

    const earlierPrice = Number(earlierRate.rate.oracle.formattedPrice);
    const latestPrice = Number(latestRate.oracle.formattedPrice);

    return ((latestPrice - earlierPrice) / earlierPrice) * 100;
  }
}
```

### Integration with Pool Balances

```typescript
// Combined pool monitoring
async function getCompletePoolStatus(params: {
  chainKey: SupportedChainId;
  protocol: ProtocolConfig;
}) {
  const [balances, rates] = await Promise.all([getPoolBalances(params), getTradingRate(params)]);

  // Combine data for comprehensive analysis
  const status = {
    liquidity: {
      inToken: balances.tokenIn.formattedBalance,
      outToken: balances.tokenOut.formattedBalance,
      ratio: balances.balanceRatio,
    },
    pricing: {
      oracleRate: rates.rate.oracleRate,
      effectiveRate: rates.rate.effectiveRate,
      fee: rates.fee.percentage,
    },
    contracts: {
      pool: balances.poolAddress,
      oracle: rates.oracleAddress,
      sender: balances.senderAddress,
    },
    health: assessPoolHealth(balances, rates),
  };

  return status;
}

function assessPoolHealth(balances: PoolBalanceResult, rates: TradingRateResult) {
  // Simplified health assessment
  const outBalance = Number(formatEther(balances.tokenOut.balance));
  const heartbeat = Number(rates.oracle.heartbeat);

  const issues = [];
  if (outBalance < 1.0) issues.push('Low output token liquidity');
  if (heartbeat > 86400) issues.push('Stale oracle data');

  return {
    status: issues.length === 0 ? 'Healthy' : 'Issues detected',
    issues,
  };
}
```

### Real-Time Rate Monitoring

```typescript
// WebSocket-style rate monitoring (pseudo-code pattern)
async function startRateMonitoring(params: TradingRateParams, intervalMs: number = 60000) {
  const monitor = new RateMonitor();

  setInterval(async () => {
    try {
      const rate = await monitor.updateRate(params.chainKey, params.protocol);

      // Check for significant changes
      const change = monitor.calculateRateChange(1); // 1 hour change
      if (change && Math.abs(change) > 5) {
        // 5% threshold
        console.log(`🚨 Significant rate change: ${change.toFixed(2)}%`);
      }

      // Log current status
      console.log(`Rate Update: ${rate.rate.effectiveRate} (Fee: ${rate.fee.percentage})`);
    } catch (error) {
      console.error('Rate monitoring error:', error);
    }
  }, intervalMs);
}

// Usage
startRateMonitoring({ chainKey: 'BASE_MAINNET', protocol: LIDO_PROTOCOL });
```

### Errors

| Error                               | When                      | Resolution                |
| ----------------------------------- | ------------------------- | ------------------------- |
| `Protocol not supported on {chain}` | Invalid chainKey/protocol | Use supported combination |
| `Oracle data unavailable`           | Oracle contract issues    | Check oracle contract     |
| `Pool data fetch failed`            | RPC connectivity          | Check RPC endpoints       |
| `Price feed stale`                  | Oracle not updating       | Wait for oracle update    |

### Common Error Handling

```typescript
try {
  const rates = await getTradingRate(params);

  // Validate oracle freshness
  const maxAge = 24 * 60 * 60; // 24 hours
  if (Number(rates.oracle.heartbeat) > maxAge) {
    console.warn('Oracle data may be stale');
  }
} catch (error) {
  if (error.message.includes('not supported')) {
    console.error('Chain/protocol not supported');
  } else if (error.message.includes('Oracle')) {
    console.error('Oracle data issue:', error.message);
  } else if (error.message.includes('fetch failed')) {
    console.error('Network connectivity issue');
  } else {
    console.error('Unexpected error:', error.message);
  }
}
```

## Performance Optimization

### Batch Data Fetching

```typescript
// Efficient multi-chain monitoring
async function batchPoolMonitoring(chains: SupportedChainId[], protocol: ProtocolConfig) {
  const results = await Promise.allSettled([
    ...chains.map(chainKey => getPoolBalances({ chainKey, protocol })),
    ...chains.map(chainKey => getTradingRate({ chainKey, protocol })),
  ]);

  const balances = results.slice(0, chains.length);
  const rates = results.slice(chains.length);

  return chains.map((chainKey, index) => ({
    chainKey,
    balances: balances[index].status === 'fulfilled' ? balances[index].value : null,
    rates: rates[index].status === 'fulfilled' ? rates[index].value : null,
    errors: {
      balances: balances[index].status === 'rejected' ? balances[index].reason : null,
      rates: rates[index].status === 'rejected' ? rates[index].reason : null,
    },
  }));
}
```

### Caching Strategy

```typescript
// Simple caching for rate data
class PoolDataCache {
  private cache = new Map<string, { data: any; timestamp: number }>();
  private ttl = 30000; // 30 seconds

  private getCacheKey(chainKey: SupportedChainId, protocol: ProtocolConfig, type: string) {
    return `${chainKey}-${protocol.name}-${type}`;
  }

  async getPoolBalances(params: PoolBalanceParams) {
    const key = this.getCacheKey(params.chainKey, params.protocol, 'balances');
    const cached = this.cache.get(key);

    if (cached && Date.now() - cached.timestamp < this.ttl) {
      return cached.data;
    }

    const data = await getPoolBalances(params);
    this.cache.set(key, { data, timestamp: Date.now() });
    return data;
  }
}
```

## Related APIs

- **[Fast Stake API](../fastStake/README.md)** - Uses pool data for liquidity validation
- **[Slow Stake API](../slowStake/README.md)** - Alternative when pool liquidity is insufficient
- **[Allowance API](../allowance/README.md)** - Token approvals for pool interactions

## Integration Examples

For complete integration examples, see:

- **[Pool Examples](../../examples/lido/README.md#pool-balance-monitoring)** - Comprehensive pool monitoring
- **[Rate Examples](../../examples/lido/README.md#trading-rate-analysis)** - Trading rate analysis
