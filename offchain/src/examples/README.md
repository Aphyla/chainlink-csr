# Examples

Examples for liquid staking protocols using the ChainLink CSR framework.

## Structure

Examples are organized by protocol:

```
src/examples/
├── lido/                    # Lido liquid staking examples
│   ├── estimateExample.ts   # Fast stake estimation
│   ├── poolBalanceExample.ts # Pool balance monitoring
│   ├── tradingRateExample.ts # Trading rate analysis
│   └── README.md           # Lido-specific documentation
└── README.md               # This file
```

## Available Protocols

### Lido

- **Input/Output**: WETH → wstETH
- **Networks**: Optimism, Arbitrum One, Base
- **Documentation**: [lido/README.md](./lido/README.md)
- **Run examples**:
  ```bash
  yarn example:lido:estimate   # Fast stake estimation
  yarn example:lido:pool       # Pool balance queries
  yarn example:lido:trading    # Trading rate analysis
  ```

## Example Types

Each protocol includes three types of examples:

### 1. Fast Stake Estimation

**File**: `estimateExample.ts`
**Purpose**: Calculate expected outputs and validate liquidity before transactions

**Shows**:

- Expected token outputs for various input amounts
- Fee calculations and effective exchange rates
- Pool liquidity validation
- Contract addresses and token metadata

### 2. Pool Balance Monitoring

**File**: `poolBalanceExample.ts`  
**Purpose**: Monitor pool liquidity across supported networks

**Shows**:

- Current token balances in each pool
- Pool composition ratios
- Liquidity health indicators
- Cross-chain comparison

### 3. Trading Rate Analysis

**File**: `tradingRateExample.ts`
**Purpose**: Analyze current exchange rates and fee structures

**Shows**:

- Oracle price data
- Pool fees and effective rates
- Price feed freshness (heartbeat)
- Calculation breakdowns

## Protocol Configuration

Examples use protocol-specific configurations:

```typescript
import { estimateFastStake, LIDO_PROTOCOL, BASE_MAINNET } from '../../index';

const result = await estimateFastStake({
  chainKey: BASE_MAINNET,
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
});
```

## Architecture

The framework separates concerns:

- **Use cases** (`src/useCases/`): Protocol-agnostic business logic
- **Examples** (`src/examples/`): Protocol-specific implementations
- **Configuration** (`src/config/`): Protocol addresses and settings

This allows:

- Adding new protocols without changing core logic
- Consistent APIs across different protocols
- Protocol-specific examples and documentation

## Development Patterns

### Adding a New Protocol

1. **Create protocol configuration** in `src/config/protocols/`
2. **Add example directory** `src/examples/{protocol}/`
3. **Copy and adapt** examples from existing protocol
4. **Update package.json** with new example scripts
5. **Create protocol-specific README**

### Example Structure Template

```typescript
// Standard imports using @/ alias
import { estimateFastStake, PROTOCOL_CONFIG } from '@/index';
import { parseEther } from 'ethers';

// Example implementation
async function runExample() {
  const result = await estimateFastStake({
    chainKey: 'BASE_MAINNET',
    amountIn: parseEther('1.0'),
    protocol: PROTOCOL_CONFIG,
  });

  // Display results
  console.log(`Expected output: ${result.amountOut}`);
}

runExample().catch(console.error);
```

## Requirements

- Node.js 18+
- Yarn package manager
- RPC endpoints configured in `.env`
- Internet connection for on-chain data

## Troubleshooting

**RPC errors**: Check your `.env` file has valid RPC URLs
**Build errors**: Run `yarn build` to compile TypeScript
**Type errors**: Run `yarn typecheck` to validate types
**Network issues**: Some examples may fail if RPC providers have rate limits

## Next Steps

1. Start with a protocol you want to integrate (e.g., Lido)
2. Read the protocol-specific README
3. Run the examples to see live data
4. Adapt the patterns for your use case
