# Examples

Examples for liquid staking protocols using the ChainLink CSR framework.

This collection demonstrates both **fast staking** (instant swaps via oracle pools) and **slow staking** (cross-chain operations via CCIP) with comprehensive tracking and monitoring capabilities.

## Structure

Examples are organized by protocol:

```
src/examples/
├── lido/                          # Lido liquid staking examples
│   ├── estimateExample.ts         # Fast stake estimation
│   ├── poolBalanceExample.ts      # Pool balance monitoring
│   ├── tradingRateExample.ts      # Trading rate analysis
│   ├── allowanceExample.ts        # TOKEN allowance checking
│   ├── fastStakeNativeExample.ts  # Fast stake with native ETH
│   ├── fastStakeWrappedExample.ts # Fast stake with WETH
│   ├── slowStakeEstimateExample.ts # Slow stake fee estimation
│   ├── slowStakeNativeExample.ts  # Slow stake with native ETH
│   ├── slowStakeNativeLinkExample.ts # Slow stake with native ETH + LINK
│   ├── slowStakeWrappedNativeExample.ts # Slow stake with WETH + native ETH
│   ├── slowStakeWrappedLinkExample.ts # Slow stake with WETH + LINK
│   └── README.md                  # Lido-specific documentation
└── README.md                      # This file
```

## Available Protocols

### Lido

- **Input/Output**: WETH → wstETH
- **Networks**: Optimism, Arbitrum One, Base
- **Fast Stake**: Instant swaps via oracle pools
- **Slow Stake**: Cross-chain staking via CCIP (Base/Arbitrum/Optimism → Ethereum → Origin)
- **Documentation**: [lido/README.md](./lido/README.md)
- **Run examples**:

  ```bash
  # Information & Analysis
  yarn example:lido:estimate-faststake      # Fast stake estimation
  yarn example:lido:estimate-slowstake      # Slow stake fee estimation
  yarn example:lido:pool                    # Pool balance queries
  yarn example:lido:trading                 # Trading rate analysis
  yarn example:lido:allowance               # TOKEN allowance checking

  # Fast Stake Execution (Instant swap via oracle pool)
  yarn example:lido:fast-stake-native       # Fast stake with native ETH
  yarn example:lido:fast-stake-wrapped      # Fast stake with WETH

  # Slow Stake Execution (Cross-chain via CCIP, ~50 min total)
  yarn example:lido:slow-stake-native       # Slow stake with native ETH
  yarn example:lido:slow-stake-native-link  # Slow stake with native ETH + LINK
  yarn example:lido:slow-stake-wrapped-native # Slow stake with WETH + native ETH
  yarn example:lido:slow-stake-wrapped-link      # Slow stake with WETH + LINK
  ```

## Staking Methods

The framework supports two distinct staking approaches:

### Fast Stake

- **Mechanism**: Instant token swaps via oracle pools
- **Speed**: Immediate execution (1 transaction)
- **Requirements**: Sufficient pool liquidity
- **Use case**: Quick trades when liquidity is available

### Slow Stake

- **Mechanism**: Cross-chain operations via Chainlink CCIP
- **Speed**: ~50 minutes total (O→D: 10-20 min, D→O: 30-40 min)
- **Requirements**: CCIP fees (ETH or LINK)
- **Use case**: Always available, regardless of pool liquidity

## Example Types

Each protocol includes several types of examples:

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

### 4. Allowance Checking

**File**: `allowanceExample.ts`
**Purpose**: Check ERC20 token allowances for wrapped token operations

**Shows**:

- Current user allowances to CustomSender contracts
- Token balance information
- Required approval actions
- Multi-chain allowance status

### 5. Transaction Execution - Native ETH

**File**: `fastStakeNativeExample.ts`
**Purpose**: Execute complete fastStakeReferral transactions using native ETH

**Shows**:

- Live transaction execution and monitoring
- Native ETH payment flow (no allowances needed)
- Event decoding and result analysis
- Performance comparison vs estimates

### 6. Transaction Execution - Wrapped Tokens

**File**: `fastStakeWrappedExample.ts`
**Purpose**: Execute complete fastStakeReferral transactions using wrapped tokens

**Shows**:

- Automatic allowance management and approval
- Wrapped token payment flow with approvals
- Transaction monitoring for both approval and execution
- Comprehensive gas cost analysis

### 7. Slow Stake Fee Estimation

**File**: `slowStakeEstimateExample.ts`
**Purpose**: Calculate cross-chain fees and requirements before slow stake transactions

**Shows**:

- CCIP fee estimation (Origin → Destination)
- Bridge fee calculation (Destination → Origin)
- Total ETH/LINK requirements breakdown
- Cross-chain timing expectations (~50 minutes total)

### 8. Transaction Execution - Slow Stake Native ETH

**File**: `slowStakeNativeExample.ts`
**Purpose**: Execute complete cross-chain liquid staking using only native ETH

**Shows**:

- Cross-chain message creation via CCIP
- Native ETH payment for both staking and CCIP fees
- CCIP message tracking with comprehensive instructions
- Complete O→D→O journey monitoring (Base → Ethereum → Base)

### 9. Transaction Execution - Slow Stake Native + LINK

**File**: `slowStakeNativeLinkExample.ts`
**Purpose**: Execute cross-chain staking with native ETH + LINK fee payments

**Shows**:

- Native ETH staking with LINK CCIP fees (cost optimization approach)
- Single-token allowance management (LINK only)
- Balance checking for multiple token types (ETH + LINK)
- Hybrid fee payment while maintaining simplicity
- Cross-chain tracking with detailed cost comparisons

### 10. Transaction Execution - Slow Stake Wrapped + Native

**File**: `slowStakeWrappedNativeExample.ts`
**Purpose**: Execute cross-chain staking with WETH + native ETH fee payments

**Shows**:

- WETH staking with native ETH CCIP fees (hybrid approach)
- Single-token allowance management (WETH only)
- Simplified fee payment while maintaining precision
- Balance checking for multiple token types
- Cross-chain tracking with detailed cost comparisons

### 11. Transaction Execution - Slow Stake Wrapped + LINK

**File**: `slowStakeWrappedLinkExample.ts`
**Purpose**: Execute cross-chain staking with WETH + LINK fee payments

**Shows**:

- Dual-token allowance management (WETH + LINK)
- Complex fee payment splitting (WETH for staking, LINK for CCIP, ETH for bridge)
- Triple balance checking (ETH + WETH + LINK)
- Multi-chain transaction coordination
- Advanced cross-chain tracking and verification

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
  - `fastStake/`: Oracle pool operations
  - `slowStake/`: Cross-chain CCIP operations
  - `allowance/`: ERC20 token management
- **Examples** (`src/examples/`): Protocol-specific implementations
- **Configuration** (`src/config/`): Protocol addresses and CCIP settings

This allows:

- Adding new protocols without changing core logic
- Consistent APIs across different protocols and staking methods
- Protocol-specific examples and documentation
- Unified cross-chain and single-chain operations

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

1. **Choose your staking method**:

   - Fast stake for immediate execution (if pool has liquidity)
   - Slow stake for guaranteed execution (always available)

2. **Start with analysis examples**:

   - `yarn example:lido:estimate-faststake` - Check pool liquidity
   - `yarn example:lido:estimate-slowstake` - Check cross-chain fees

3. **Run execution examples**:

   - Start with native examples (simpler, no approvals needed)
   - Progress to wrapped examples (more complex, with allowances)

4. **Monitor your transactions**:

   - Fast stake: Monitor single transaction on origin chain
   - Slow stake: Track CCIP message + cross-chain delivery (~50 min)

5. **Adapt the patterns** for your specific use case
