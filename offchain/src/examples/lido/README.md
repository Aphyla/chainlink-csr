# Lido Examples

Examples for interacting with Lido's liquid staking protocol using the ChainLink CSR framework.

## Overview

Lido protocol allows users to stake ETH and receive wstETH (wrapped staked ETH) in return. These examples demonstrate fast staking operations where users get wstETH immediately from a pool rather than waiting for L1 staking.

**Protocol Details**:

- **Input Token**: WETH (Wrapped Ether)
- **Output Token**: wstETH (Wrapped Staked Ether)
- **Networks**: Optimism, Arbitrum One, Base
- **Price Source**: Chainlink wstETH/WETH oracle

## Quick Start

```bash
yarn example:lido:estimate   # Fast stake estimation
yarn example:lido:pool       # Pool balance monitoring
yarn example:lido:trading    # Trading rate analysis
```

## Examples

### 1. Fast Stake Estimation (`estimateExample.ts`)

Calculates expected wstETH output for given WETH input amounts.

**What it does**:

- Tests estimation for 0.1, 1.0, and 5.0 WETH amounts
- Shows fee calculations and effective exchange rates
- Validates pool has sufficient wstETH liquidity
- Displays contract addresses and token metadata

**Use case**: Preview transaction outcomes before execution

**Sample output**:

```
Testing Lido Fast Stake Estimation on Base
Estimating 1.0 WETH...
Expected Output: 0.829739 wstETH
Pool Liquidity: ✅ Sufficient
```

### 2. Pool Balance Monitoring (`poolBalanceExample.ts`)

Checks current token balances in Lido pools across all supported networks.

**What it does**:

- Queries WETH and wstETH balances in each pool
- Calculates balance ratios and pool composition
- Assesses pool health and sync requirements
- Shows contract addresses for each network

**Use case**: Monitor liquidity before large transactions

**Sample output**:

```
Lido Pool Balance Query
Checking Base (Chain ID: 8453)
WETH: 0.151001 WETH
wstETH: 31.433574 wstETH
Balance Ratio: 208.168 wstETH/WETH
Status: ✅ Pool appears healthy
```

### 3. Trading Rate Analysis (`tradingRateExample.ts`)

Analyzes current exchange rates and fee structures.

**What it does**:

- Fetches current wstETH/WETH rates from Chainlink oracle
- Shows pool fees and their impact on effective rates
- Displays oracle heartbeat and data freshness
- Provides calculation examples

**Use case**: Display current rates and understand pricing

**Sample output**:

```
Lido Trading Rate Query
Trading Pair: WETH → wstETH
Oracle Rate: 1 WETH = 1.205197 wstETH
Effective Rate: 1 WETH = 1.205197 wstETH (0% fee)
```

## Configuration

All examples use the Lido protocol configuration:

```typescript
import { estimateFastStake, LIDO_PROTOCOL, BASE_MAINNET } from '../../index';

const result = await estimateFastStake({
  chainKey: BASE_MAINNET,
  amountIn: parseEther('1.0'),
  protocol: LIDO_PROTOCOL,
});
```

## Contract Architecture

**CustomSender**: Entry point for fast stake operations
**OraclePool**: Manages WETH ↔ wstETH swaps and maintains liquidity
**PriceOracle**: Chainlink price feed providing wstETH/WETH exchange rates
**Tokens**: WETH (input) and wstETH (output) token contracts

## Pool Mechanics

1. **Fast Stakes**: Users deposit WETH and receive wstETH immediately from pool reserves
2. **Pool Sync**: Accumulated WETH is periodically staked on L1 Ethereum to mint new wstETH
3. **Liquidity**: Pool maintains wstETH reserves for instant swaps
4. **Fees**: Currently 0% for Lido pools (configurable per pool)

## Oracle Data

- **Price Source**: Chainlink wstETH/WETH price feed
- **Update Frequency**: 24-hour heartbeat (86400 seconds)
- **Precision**: 18 decimals for all calculations

## Supported Networks

| Network      | Chain ID | Pool Address    | Sender Address  |
| ------------ | -------- | --------------- | --------------- |
| Optimism     | 10       | `0x6F357d53...` | `0x328de900...` |
| Arbitrum One | 42161    | `0x9c27c304...` | `0x72229141...` |
| Base         | 8453     | `0x6F357d53...` | `0x328de900...` |

## Integration Tips

1. **Check liquidity first**: Use pool balance queries before large transactions
2. **Monitor pool health**: High WETH ratios indicate pools need sync operations
3. **Handle rate changes**: Oracle rates update daily and may fluctuate
4. **Use Base for testing**: Generally has good liquidity and lower gas costs
5. **Factor gas costs**: Consider L2 transaction costs in profitability calculations

## Common Issues

**Insufficient liquidity**: Pool may not have enough wstETH for large swaps
**Stale oracle data**: Check heartbeat to ensure recent price updates
**RPC rate limits**: Use dedicated RPC providers for production usage
**Network differences**: Each chain has different pool liquidity levels

## External Resources

- [Lido Protocol](https://lido.fi)
- [Lido Documentation](https://docs.lido.fi)
- [wstETH Guide](https://help.lido.fi/en/articles/5230610-what-is-wrapped-steth-wsteth)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
