# ChainLink CSR Offchain

TypeScript utilities for liquid staking protocols using ChainLink Custom Sender-Receiver contracts.

## What This Does

This library provides off-chain tools to interact with liquid staking pools across multiple blockchain networks. It supports:

- **Fast stake estimation** - Preview swap amounts and fees before transactions
- **Pool balance monitoring** - Check liquidity across supported chains
- **Trading rate analysis** - Get current exchange rates and oracle data
- **Transaction execution** - Execute fastStakeReferral with native ETH or WETH
- **Allowance management** - Check and approve ERC20 token allowances

Currently supports Lido (WETH → wstETH) on Optimism, Arbitrum One, and Base networks.

## Quick Start

1. **Install dependencies**

   ```bash
   yarn install
   ```

2. **Configure environment**

   ```bash
   cp .env.example .env
   # Edit .env with your RPC URLs
   ```

3. **Build project**

   ```bash
   yarn build
   ```

4. **Run examples**
   ```bash
   yarn example:lido:estimate      # Test fast stake estimation
   yarn example:lido:pool          # Check pool balances
   yarn example:lido:trading       # View current trading rates
   yarn example:lido:allowance     # Check TOKEN allowances
   yarn example:lido:fast-stake-native  # Execute with native ETH
   yarn example:lido:fast-stake-wrapped # Execute with WETH
   yarn example:lido:estimate-slowstake   # SlowStake fee estimation (multi-chain)
   ```

## Examples

See [`src/examples/`](src/examples/) for complete examples organized by protocol:

- **Lido examples**: [`src/examples/lido/`](src/examples/lido/)
- **Documentation**: Each protocol directory contains detailed usage guides

## Library Usage

```typescript
import { estimateFastStake, LIDO_PROTOCOL, BASE_MAINNET } from '@chainlink/csr-offchain';
import { parseEther } from 'ethers';

// Estimate a 1 WETH fast stake on Lido
const result = await estimateFastStake({
  chainKey: BASE_MAINNET,
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
});

console.log(`Expected output: ${result.amountOut} wstETH`);
```

All functions are protocol-agnostic and require a `protocol` parameter to specify which liquid staking protocol to use.

## Development Commands

| Command            | Purpose                           |
| ------------------ | --------------------------------- |
| `yarn build`       | Compile TypeScript to JavaScript  |
| `yarn build:watch` | Compile with file watching        |
| `yarn dev`         | Run with hot reload               |
| `yarn lint`        | Run ESLint                        |
| `yarn typecheck`   | Type checking without compilation |
| `yarn typechain`   | Generate contract types from ABIs |
| `yarn clean`       | Remove build artifacts            |

## Environment Configuration

Required environment variables in `.env`:

```bash
# RPC endpoints for supported networks
ETHEREUM_RPC_URL=https://...
ARBITRUM_RPC_URL=https://...
OPTIMISM_RPC_URL=https://...
BASE_RPC_URL=https://...

# Private keys (for automation/operator functions)
OPERATOR_PRIVATE_KEY=0x...
AUTOMATION_PRIVATE_KEY=0x...
```

## Architecture

```
src/
├── core/           # Protocol-agnostic utilities
│   ├── contracts/  # Contract setup and connections
│   ├── tokens/     # Token metadata and balances
│   └── oracle/     # Price feed and oracle data
├── config/         # Protocol configurations
├── useCases/       # Main business logic functions
└── examples/       # Protocol-specific examples
```

**Import Conventions:**

- Use `@/` alias for all cross-directory imports (e.g., `@/core/protocols/interfaces`, `@/useCases/fastStake/estimate`)
- Use `./` for same-directory imports only (e.g., `./interfaces`)
- All files consistently use `@/` for imports from other directories

## Supported Networks

| Network          | Chain ID | Status    |
| ---------------- | -------- | --------- |
| Optimism Mainnet | 10       | ✅ Active |
| Arbitrum One     | 42161    | ✅ Active |
| Base Mainnet     | 8453     | ✅ Active |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run `yarn lint` and `yarn typecheck`
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
