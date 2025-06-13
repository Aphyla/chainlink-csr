# Fast Stake API Reference

Instant liquid staking operations via oracle pools. These functions enable immediate token swaps when sufficient liquidity is available in the pools.

## Overview

Fast stake operations provide instant execution:

1. **User sends tokens** to the pool contract
2. **Immediate swap** using oracle pricing
3. **Instant receipt** of staked tokens from pool reserves

**Execution time**: Immediate (single transaction)
**Requirement**: Sufficient pool liquidity

## Functions

- [`estimateFastStake()`](#estimatefaststake) - Calculate expected outputs and validate liquidity
- [`executeFastStake()`](#executefaststake) - Execute instant swap transactions (Note: Implementation may vary)

---

## `estimateFastStake()`

Calculates expected liquid staking token output for a given input amount, including comprehensive fee breakdown, oracle pricing, and pool liquidity validation.

### Function Signature

```typescript
function estimateFastStake(params: EstimateFastStakeParams): Promise<EstimateFastStakeResult>;
```

### Parameters

```typescript
interface EstimateFastStakeParams {
  /** Supported chain ID for operations */
  chainKey: SupportedChainId;
  /** Amount of TOKEN_IN (WETH) provided by the user, in wei */
  amountIn: bigint;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
}
```

### Returns

```typescript
interface EstimateFastStakeResult {
  /** Expected LST tokens returned by fastStake, in wei */
  readonly amountOut: bigint;

  // Detailed fee breakdown
  readonly fees: FeeBreakdown;

  // Oracle and pricing details
  readonly pricing: PriceInfo;

  // Pool liquidity information
  readonly pool: PoolInfo;

  // Contract addresses and token info
  readonly contracts: ContractInfo;

  /** Effective exchange rate: amountOut / amountIn (1e18 scale) */
  readonly effectiveRate: bigint;
}
```

#### Return Type Details

```typescript
interface FeeBreakdown {
  /** Fee percentage (1e18 scale) - e.g., 1e16 = 1% */
  readonly feeRate: bigint;
  /** Absolute fee amount in TOKEN_IN, in wei */
  readonly feeAmount: bigint;
  /** Amount after fee deduction, in wei */
  readonly amountAfterFee: bigint;
}

interface PriceInfo {
  /** Current oracle price (1e18 scale) */
  readonly price: bigint;
  /** Price oracle address */
  readonly oracleAddress: Address;
  /** Whether price oracle is inverse (rare case) */
  readonly isInverse: boolean;
  /** Oracle heartbeat (max staleness) */
  readonly heartbeat: bigint;
}

interface PoolInfo {
  /** Available TOKEN_OUT balance in pool */
  readonly availableOut: bigint;
  /** Whether pool has sufficient liquidity for this swap */
  readonly hasSufficientLiquidity: boolean;
  /** Pool sender (CustomSender address) */
  readonly poolSender: Address;
}

interface ContractInfo {
  readonly customSender: Address;
  readonly oraclePool: Address;
  readonly priceOracle: Address;
  readonly tokenIn: TokenInfo; // Usually WETH
  readonly tokenOut: TokenInfo; // Usually wstETH
  readonly wnative: Address;
  readonly linkToken: Address;
}
```

### Calculation Logic

The function reproduces the exact on-chain math performed by `OraclePool.swap`:

```typescript
// 1. Calculate fee
feeAmount = (amountIn * feeRate) / 1e18;

// 2. Calculate amount after fee
amountAfterFee = amountIn - feeAmount;

// 3. Calculate output using oracle price
amountOut = (amountAfterFee * 1e18) / oraclePrice;
```

### Usage Example

```typescript
import { estimateFastStake, LIDO_PROTOCOL } from '@chainlink/csr-offchain';
import { parseEther, formatEther } from 'ethers';

const estimation = await estimateFastStake({
  chainKey: 'BASE_MAINNET',
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
});

console.log(`Input: ${formatEther(estimation.contracts.tokenIn.address)} WETH`);
console.log(`Expected Output: ${formatEther(estimation.amountOut)} wstETH`);
console.log(`Fee: ${formatEther(estimation.fees.feeAmount)} WETH`);
console.log(
  `Pool Liquidity: ${estimation.pool.hasSufficientLiquidity ? '✅ Sufficient' : '❌ Insufficient'}`
);
```

### Liquidity Validation

```typescript
const estimation = await estimateFastStake(params);

if (!estimation.pool.hasSufficientLiquidity) {
  console.warn(
    `Insufficient liquidity. Need ${formatEther(estimation.amountOut)} but pool only has ${formatEther(estimation.pool.availableOut)}`
  );
  // Consider using slow stake instead
}
```

### Oracle Data Analysis

```typescript
const estimation = await estimateFastStake(params);
const { pricing } = estimation;

console.log(`Oracle Price: ${formatEther(pricing.price)} WETH per wstETH`);
console.log(`Oracle Heartbeat: ${pricing.heartbeat} seconds`);
console.log(`Oracle Address: ${pricing.oracleAddress}`);

// Check if oracle data is recent
const maxStaleness = Number(pricing.heartbeat);
const now = Date.now() / 1000;
// Note: You'd need additional on-chain calls to get the last update timestamp
```

### Errors

| Error                               | When                          | Resolution           |
| ----------------------------------- | ----------------------------- | -------------------- |
| `Protocol not supported on {chain}` | Invalid chainKey for protocol | Use supported chain  |
| `Oracle price not available`        | Oracle data issues            | Check oracle status  |
| `Token metadata fetch failed`       | RPC connectivity issues       | Verify RPC endpoints |

---

## `executeFastStake()`

> **Note**: This function may not be implemented in all versions. Check your specific implementation for availability.

Execute instant swap transactions with automatic allowance management (for wrapped tokens) and slippage protection.

### Expected Function Signature

```typescript
function executeFastStake(params: ExecuteFastStakeParams): Promise<ExecuteFastStakeResult>;
```

### Expected Parameters

```typescript
interface ExecuteFastStakeParams {
  /** Supported chain ID for operations */
  chainKey: SupportedChainId;
  /** Amount of TOKEN_IN to swap, in wei */
  amountIn: bigint;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
  /** Signer to execute the transaction */
  signer: Signer;
  /** Minimum amount out (slippage protection), in wei */
  minAmountOut?: bigint;
  /** Payment method: 'native' for ETH, 'wrapped' for TOKEN_IN */
  paymentMethod?: PaymentMethod;
  /** Whether to auto-approve unlimited allowance (default: false) */
  autoApproveUnlimited?: boolean;
  /** Pre-calculated estimation (optional optimization) */
  estimation?: EstimateFastStakeResult;
}
```

### Expected Returns

```typescript
interface ExecuteFastStakeResult {
  readonly transactionHash: string;
  readonly amountOut: bigint;
  readonly estimation: EstimateFastStakeResult;
  readonly actualRate: bigint;
  readonly slippageProtection: {
    readonly minAmountOut: bigint;
    readonly actualAmountOut: bigint;
    readonly slippagePercent: string;
  };
}
```

### Usage Pattern

```typescript
// 1. Estimate first
const estimation = await estimateFastStake({
  chainKey: 'BASE_MAINNET',
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
});

// 2. Check liquidity
if (!estimation.pool.hasSufficientLiquidity) {
  throw new Error('Insufficient pool liquidity');
}

// 3. Calculate slippage protection (e.g., 2% tolerance)
const slippagePercent = 2;
const minAmountOut = (estimation.amountOut * BigInt(100 - slippagePercent)) / 100n;

// 4. Execute (if function is available)
const result = await executeFastStake({
  chainKey: 'BASE_MAINNET',
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
  signer: wallet,
  minAmountOut,
  paymentMethod: 'native',
  estimation, // Reuse calculation
});
```

## Pool Liquidity Monitoring

### Check Before Large Transactions

```typescript
import { getPoolBalances } from '../pool/balance';

// Check current pool state
const poolInfo = await getPoolBalances({
  chainKey: 'BASE_MAINNET',
  protocol: LIDO_PROTOCOL,
});

console.log(`Pool TOKEN_OUT: ${formatEther(poolInfo.tokenOut.balance)} wstETH`);
console.log(`Pool TOKEN_IN: ${formatEther(poolInfo.tokenIn.balance)} WETH`);

// Estimate large transaction
const largeAmount = parseEther('10.0');
const estimation = await estimateFastStake({
  chainKey: 'BASE_MAINNET',
  amountIn: largeAmount,
  protocol: LIDO_PROTOCOL,
});

if (!estimation.pool.hasSufficientLiquidity) {
  console.log('Consider splitting into smaller transactions or using slow stake');
}
```

### Dynamic Slippage Calculation

```typescript
function calculateDynamicSlippage(amountOut: bigint, availableOut: bigint): number {
  const utilizationPercent = Number((amountOut * 100n) / availableOut);

  if (utilizationPercent < 10) return 1; // 1% for small trades
  if (utilizationPercent < 50) return 2; // 2% for medium trades
  return 5; // 5% for large trades
}

const estimation = await estimateFastStake(params);
const slippagePercent = calculateDynamicSlippage(
  estimation.amountOut,
  estimation.pool.availableOut
);
```

## Performance Optimization

### Parallel Data Fetching

```typescript
// Fetch pool data and estimation in parallel
const [estimation, poolBalances, tradingRate] = await Promise.all([
  estimateFastStake(params),
  getPoolBalances({ chainKey: params.chainKey, protocol: params.protocol }),
  getTradingRate({ chainKey: params.chainKey, protocol: params.protocol }),
]);

// Use combined data for decision making
```

### Estimation Reuse

```typescript
// Calculate estimation once
const estimation = await estimateFastStake(params);

// Reuse for multiple operations
if (estimation.pool.hasSufficientLiquidity) {
  // Pass estimation to execution to avoid recalculation
  const result = await executeFastStake({
    ...params,
    signer: wallet,
    estimation,
  });
}
```

## Error Handling

### Common Error Patterns

```typescript
try {
  const estimation = await estimateFastStake(params);

  // Check critical conditions
  if (!estimation.pool.hasSufficientLiquidity) {
    throw new Error(
      `Insufficient liquidity: need ${formatEther(estimation.amountOut)} but pool only has ${formatEther(estimation.pool.availableOut)}`
    );
  }

  // Proceed with execution
} catch (error) {
  if (error.message.includes('not supported')) {
    console.error('Protocol/chain combination not supported');
  } else if (error.message.includes('Oracle')) {
    console.error('Oracle pricing issue:', error.message);
  } else if (error.message.includes('liquidity')) {
    console.error('Pool liquidity issue:', error.message);
    // Suggest slow stake as alternative
  } else {
    console.error('Unexpected error:', error.message);
  }
}
```

### Oracle Validation

```typescript
const estimation = await estimateFastStake(params);

// Check oracle freshness
const maxAge = 24 * 60 * 60; // 24 hours in seconds
if (Number(estimation.pricing.heartbeat) > maxAge) {
  console.warn('Oracle heartbeat longer than 24 hours');
}

// Validate price reasonableness (implementation specific)
const expectedRateRange = { min: 0.8, max: 1.2 }; // Example bounds
const actualRate = Number(formatEther(estimation.effectiveRate));
if (actualRate < expectedRateRange.min || actualRate > expectedRateRange.max) {
  console.warn('Exchange rate outside expected range:', actualRate);
}
```

## Related APIs

- **[Slow Stake API](../slowStake/README.md)** - Alternative when pool liquidity is insufficient
- **[Pool API](../pool/README.md)** - For monitoring pool liquidity and rates
- **[Allowance API](../allowance/README.md)** - For advanced token allowance management

## Integration Examples

For complete integration examples, see:

- **[Fast Stake Examples](../../examples/lido/README.md#fast-stake-execution)** - Native and wrapped token implementations
- **[Tutorial Examples](../../examples/README.md)** - Step-by-step implementation guides
