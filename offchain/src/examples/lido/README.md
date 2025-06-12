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
yarn example:lido:estimate      # Fast stake estimation
yarn example:lido:pool          # Pool balance monitoring
yarn example:lido:trading       # Trading rate analysis
yarn example:lido:allowance     # TOKEN allowance checking
yarn example:lido:fast-stake-native  # Execute fastStake with native ETH
yarn example:lido:fast-stake-wrapped # Execute fastStake with WETH
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

### 4. TOKEN Allowance Checking (`allowanceExample.ts`)

Checks TOKEN allowances for users across all supported networks.

**What it does**:

- Retrieves TOKEN address from CustomSender contracts
- Checks user's current allowance to CustomSender
- Shows user balance and allowance status
- Provides actionable guidance for approvals

**Use case**: Prepare for fastStakeReferral operations

**Configuration**:

- Set `PRIVATE_KEY` environment variable to use your wallet automatically
- Or manually override `userAddress` in the code for testing with specific addresses

**Sample output**:

```
📱 Using current signer address: 0x742CCbb...
🔍 Checking Lido TOKEN Allowances for User: 0x742CCbb...
🌐 Base (Chain ID: 8453)
🪙 TOKEN Information:
  Token: WETH (Wrapped Ether)
  Address: 0x4200000000000000000000000000000000000006
💰 User Balance: 2.5 WETH
🔐 Allowance Status:
  ❌ NO ALLOWANCE
  User must approve WETH to use fastStakeReferral
🎯 Required Actions:
  📝 Approve WETH allowance to CustomSender
```

### 5. FastStake Execution - Native ETH (`fastStakeNativeExample.ts`)

Executes complete fastStakeReferral transactions using native ETH payment.

**What it does**:

- Creates wallet instance and validates parameters
- Estimates transaction and calculates slippage protection
- Executes fastStakeReferral with native ETH payment
- Monitors transaction confirmation and decodes events
- Provides comprehensive results and accuracy analysis

**Use case**: Live fastStakeReferral execution for testing and integration

**Sample output**:

```
🚀 FastStake with Native ETH on Base
Explorer: https://basescan.org

📱 Using wallet: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
💰 Staking amount: 0.001 ETH
👥 Referral: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
🛡️ Slippage tolerance: 2%

🔄 Executing fastStakeReferral with native ETH...
📊 Estimating transaction parameters...
✅ Estimation complete. Expected: 0.00082973950196012 wstETH
🛡️ Min amount out (2% slippage): 0.000813144711920917 wstETH
🚀 Executing fastStakeReferral with native payment...
⏳ Transaction submitted: 0x5bd4366f22e1b1b8439a1e1f1fe05ee349653e91d990e41d396da231e7d1ff77
📊 Waiting for confirmation...
✅ Transaction confirmed in block 31470372

🎉 Transaction Successful!
════════════════════════════════════════════════════════════════════════════════
📊 Transaction Details:
  TX Hash: 0x5bd4366f22e1b1b8439a1e1f1fe05ee349653e91d990e41d396da231e7d1ff77
  Block: 31470372
  Gas Used: 146,808
  Gas Price: 0.00476877 gwei
  Gas Cost: 0.00000070009358616 ETH
  Explorer: https://basescan.org/tx/0x5bd4366f22e1b1b8439a1e1f1fe05ee349653e91d990e41d396da231e7d1ff77

💱 Staking Summary:
  Input: 0.001 ETH (native)
  Output: 0.00082973950196012 wstETH
  Effective Rate: 0.82973950196012 wstETH/ETH

💸 Fee Breakdown:
  Pool Fee: 0%
  Fee Amount: 0.0 WETH
  Transaction Fee: 0.00000070009358616 ETH

👥 Referral Event:
  User: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
  Referral: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
  Amount Out: 0.00082973950196012 wstETH

🎯 Estimation vs Reality:
  Estimated: 0.00082973950196012 wstETH
  Actual: 0.00082973950196012 wstETH
  Difference: 0.0 wstETH
  Relative Performance: 100.00%

📋 Contract Details:
  CustomSender: 0x328de900860816d29D1367F6903a24D8ed40C997
  OraclePool: 0x6F357d53d6bE3238180316BA5F8f11467e164588
  PriceOracle: 0x301cBCDA894c932E9EDa3Cf8878f78304e69E367
  Input Token: WETH (0x4200000000000000000000000000000000000006)
  Output Token: wstETH (0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452)
```

### 6. FastStake Execution - Wrapped Token (`fastStakeWrappedExample.ts`)

Executes complete fastStakeReferral transactions using WETH payment with allowance management.

**What it does**:

- Creates wallet instance and validates parameters
- Checks and manages WETH allowance automatically
- Estimates transaction and calculates slippage protection
- Executes fastStakeReferral with WETH payment
- Monitors both approval and stake transactions
- Provides detailed allowance and execution analysis

**Use case**: Live fastStakeReferral execution with wrapped tokens

**Sample output**:

```
🚀 FastStake with Wrapped Native Token on Base
Explorer: https://basescan.org

📱 Using wallet: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
💰 Staking amount: 0.0001 WETH
👥 Referral: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
🛡️ Slippage tolerance: 2%
🔓 Auto-approve unlimited: Yes

🔄 Executing fastStakeReferral with WETH...
📊 Estimating transaction parameters...
✅ Estimation complete. Expected: 0.000082967511843517 wstETH
🛡️ Min amount out (2% slippage): 0.000081308161606646 wstETH
🔐 Checking TOKEN allowance for wrapped payment...
✅ Sufficient allowance already exists
🚀 Executing fastStakeReferral with wrapped payment...
⏳ Transaction submitted: 0xc16e46b21e14ac346dfe567d97a9e57aa81f35afb55b51457b1a0365eaedaf5a
📊 Waiting for confirmation...
✅ Transaction confirmed in block 31472367

🎉 Transaction Successful!
════════════════════════════════════════════════════════════════════════════════
🔐 Allowance Management:
  Initial Allowance: Unlimited (MaxUint256)
  ✅ Sufficient Allowance Already Existed
  Current Allowance: Unlimited (MaxUint256)

📊 Transaction Details:
  TX Hash: 0xc16e46b21e14ac346dfe567d97a9e57aa81f35afb55b51457b1a0365eaedaf5a
  Block: 31472367
  Gas Used: 133,306
  Gas Price: 0.002498081 gwei
  Gas Cost: 0.000000333009185786 ETH
  Explorer: https://basescan.org/tx/0xc16e46b21e14ac346dfe567d97a9e57aa81f35afb55b51457b1a0365eaedaf5a

💱 Staking Summary:
  Input: 0.0001 WETH (wrapped)
  Output: 0.000082967511843517 wstETH
  Effective Rate: 0.82967511843517 wstETH/WETH

💸 Fee Breakdown:
  Pool Fee: 0%
  Fee Amount: 0.0 WETH
  Transaction Fee: 0.000000333009185786 ETH

👥 Referral Event:
  User: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
  Referral: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
  Amount Out: 0.000082967511843517 wstETH

🎯 Estimation vs Reality:
  Estimated: 0.000082967511843517 wstETH
  Actual: 0.000082967511843517 wstETH
  Difference: 0.0 wstETH
  Relative Performance: 100.00%

📋 Contract Details:
  CustomSender: 0x328de900860816d29D1367F6903a24D8ed40C997
  OraclePool: 0x6F357d53d6bE3238180316BA5F8f11467e164588
  PriceOracle: 0x301cBCDA894c932E9EDa3Cf8878f78304e69E367
  Input Token: WETH (0x4200000000000000000000000000000000000006)
  Output Token: wstETH (0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452)
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

1. **Set up environment**: Create `.env` file with `PRIVATE_KEY=your_private_key_here` for automatic wallet usage
2. **Choose payment method**: Native ETH for simplicity, WETH for precision and integration
3. **Check liquidity first**: Use pool balance queries before large transactions
4. **Verify allowances**: Check TOKEN allowances before wrapped token operations
5. **Monitor pool health**: High WETH ratios indicate pools need sync operations
6. **Handle rate changes**: Oracle rates update daily and may fluctuate
7. **Set slippage tolerance**: 1-3% typical for stable conditions, higher during volatility
8. **Use Base for testing**: Generally has good liquidity and lower gas costs
9. **Factor gas costs**: Consider L2 transaction costs and approval overhead
10. **Test small amounts**: Start with small stakes (0.01 ETH) for testing

## Common Issues

**Insufficient liquidity**: Pool may not have enough wstETH for large swaps
**Stale oracle data**: Check heartbeat to ensure recent price updates
**Insufficient allowance**: WETH operations require token approval first
**High slippage**: Transaction fails if actual rate exceeds minAmountOut
**Gas estimation errors**: Network congestion can cause gas estimation failures
**Private key missing**: Execution examples require PRIVATE_KEY environment variable
**RPC rate limits**: Use dedicated RPC providers for production usage
**Network differences**: Each chain has different pool liquidity levels

## External Resources

- [Lido Protocol](https://lido.fi)
- [Lido Documentation](https://docs.lido.fi)
- [wstETH Guide](https://help.lido.fi/en/articles/5230610-what-is-wrapped-steth-wsteth)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
