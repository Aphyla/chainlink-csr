# Use Cases API Reference

This directory contains the core business logic functions for liquid staking operations. Each module provides protocol-agnostic functions that work across different liquid staking protocols and blockchain networks.

## Overview

The use cases are organized by functionality:

```
src/useCases/
├── README.md              # This file - API overview
├── fastStake/
│   ├── README.md          # Fast stake API reference
│   ├── estimate.ts        # estimateFastStake()
│   └── execute.ts         # executeFastStake()
├── slowStake/
│   ├── README.md          # Slow stake API reference
│   ├── estimate.ts        # estimateSlowStakeFees()
│   ├── execute.ts         # executeSlowStake()
│   ├── fee-calculator.ts  # Internal fee calculations
│   └── fee-codec.ts       # Internal fee encoding
├── allowance/
│   ├── README.md          # Allowance API reference
│   └── check.ts           # checkTokenAllowance()
└── pool/
    ├── README.md          # Pool API reference
    ├── balance.ts         # getPoolBalances()
    └── trading-rate.ts    # getTradingRate()
```

## Quick Reference

| Function                                                                           | Module    | Purpose                                         |
| ---------------------------------------------------------------------------------- | --------- | ----------------------------------------------- |
| [`estimateFastStake()`](./fastStake/README.md#estimatefaststake)                   | fastStake | Calculate expected outputs for instant swaps    |
| [`executeFastStake()`](./fastStake/README.md#executefaststake)                     | fastStake | Execute instant swap transactions               |
| [`estimateSlowStakeFees()`](./slowStake/README.md#estimateslowstakefees)           | slowStake | Calculate cross-chain fees and requirements     |
| [`executeSlowStake()`](./slowStake/README.md#executeslowstake)                     | slowStake | Execute cross-chain staking operations          |
| [`validateSlowStakeExecution()`](./slowStake/README.md#validateslowstakeexecution) | slowStake | Dry-run validation without sending transactions |
| [`checkTokenAllowance()`](./allowance/README.md#checktokenallowance)               | allowance | Check ERC20 token allowances                    |
| [`getPoolBalances()`](./pool/README.md#getpoolbalances)                            | pool      | Query current pool token balances               |
| [`getTradingRate()`](./pool/README.md#gettradingrate)                              | pool      | Get current exchange rates and fees             |

## Architecture Principles

### **Protocol Agnostic**

All functions accept a `protocol` parameter and work across different liquid staking protocols (Lido, etc.)

### **Chain Agnostic**

Functions accept a `chainKey` parameter and work across supported networks (Optimism, Arbitrum, Base)

### **Type Safe**

All functions provide comprehensive TypeScript interfaces with detailed type information

### **Error Handling**

Functions throw descriptive errors with actionable messages for common failure scenarios

### **Composable**

Functions are designed to work together - estimation results can be passed to execution functions

## Common Parameters

Most functions accept these standard parameters:

```typescript
interface CommonParams {
  /** Supported chain ID for operations */
  chainKey: SupportedChainId;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
}
```

### Supported Chain IDs

- `'OPTIMISM_MAINNET'` - Optimism (Chain ID: 10)
- `'ARBITRUM_MAINNET'` - Arbitrum One (Chain ID: 42161)
- `'BASE_MAINNET'` - Base (Chain ID: 8453)

### Protocol Configurations

Import from main library:

```typescript
import { LIDO_PROTOCOL } from '@chainlink/csr-offchain';
```

## Common Patterns

### **Estimation Before Execution**

```typescript
// 1. Estimate first
const estimation = await estimateFastStake({
  chainKey: 'BASE_MAINNET',
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
});

// 2. Execute with estimation
const result = await executeFastStake({
  chainKey: 'BASE_MAINNET',
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
  signer: wallet,
  estimation, // Optional: reuse calculation
});
```

### **Error Handling**

```typescript
try {
  const result = await estimateFastStake(params);
} catch (error) {
  if (error.message.includes('Insufficient liquidity')) {
    // Handle liquidity issues
  } else if (error.message.includes('not supported')) {
    // Handle unsupported chain/protocol
  }
  throw error;
}
```

### **Balance and Allowance Checking**

```typescript
// Check allowances before execution
const allowanceInfo = await checkTokenAllowance({
  chainKey: 'BASE_MAINNET',
  userAddress: '0x...',
  protocol: LIDO_PROTOCOL,
});

// Check pool liquidity
const poolInfo = await getPoolBalances({
  chainKey: 'BASE_MAINNET',
  protocol: LIDO_PROTOCOL,
});
```

## Integration with Examples

This API reference focuses on **function contracts** - parameters, return types, and behavior. For **integration patterns** and **sample usage**, see:

- **Tutorial Examples**: [`../examples/`](../examples/) - Step-by-step guides
- **Protocol Examples**: [`../examples/lido/`](../examples/lido/) - Lido-specific implementations

## Next Steps

- **[Fast Stake API](./fastStake/README.md)** - Instant swaps via oracle pools
- **[Slow Stake API](./slowStake/README.md)** - Cross-chain operations via CCIP
- **[Allowance API](./allowance/README.md)** - ERC20 token management
- **[Pool API](./pool/README.md)** - Pool monitoring and rates
