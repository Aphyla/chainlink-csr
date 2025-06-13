# Lido Examples

Examples for interacting with Lido's liquid staking protocol using the ChainLink CSR framework.

## Overview

Lido protocol allows users to stake ETH and receive wstETH (wrapped staked ETH) in return. These examples demonstrate two staking approaches:

- **Fast Staking**: Instant swaps via oracle pools (when liquidity is available)
- **Slow Staking**: Cross-chain operations via Chainlink CCIP (~50 minutes, always available)

**Protocol Details**:

- **Input Token**: WETH (Wrapped Ether) or native ETH
- **Output Token**: wstETH (Wrapped Staked Ether)
- **Networks**: Optimism, Arbitrum One, Base → Ethereum → Origin
- **Price Source**: Chainlink wstETH/WETH oracle
- **Cross-chain**: Chainlink CCIP for slow staking

## Quick Start

```bash
# Information & Analysis
yarn example:lido:estimate-faststake      # Fast stake estimation
yarn example:lido:estimate-slowstake      # Slow stake fee estimation
yarn example:lido:pool                    # Pool balance monitoring
yarn example:lido:trading                 # Trading rate analysis
yarn example:lido:allowance               # TOKEN allowance checking

# Fast Stake Execution (Instant via oracle pools)
yarn example:lido:fast-stake-native       # Fast stake with native ETH
yarn example:lido:fast-stake-wrapped      # Fast stake with WETH

# Slow Stake Execution (Cross-chain via CCIP, ~50 min total)
yarn example:lido:slow-stake-native       # Slow stake with native ETH
yarn example:lido:slow-stake-native-link  # Slow stake with native ETH + LINK
yarn example:lido:slow-stake-wrapped-native # Slow stake with WETH + native ETH
yarn example:lido:slow-stake-wrapped-link      # Slow stake with WETH + LINK
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

### 7. Slow Stake Fee Estimation (`slowStakeEstimateExample.ts`)

Calculates cross-chain fees and requirements for slow stake operations.

**What it does**:

- Estimates CCIP fees for Origin → Destination bridging
- Calculates bridge fees for Destination → Origin return
- Shows total ETH/LINK requirements breakdown
- Provides timing expectations (~50 minutes total)

**Use case**: Calculate costs before cross-chain staking

**Sample output**:

```
🐌 Slow Stake Fee Estimation for Lido on Base

💸 Fee Breakdown:
  Staking Amount: 0.001 ETH
  CCIP Fee (O→D): 0.003055091568389173 ETH
  Bridge Fee (D→O): 0.0 ETH
  Total ETH Required: 0.004055091568389173 ETH

⏰ Timing Expectations:
  Origin → Destination: 10-20 minutes
  Destination → Origin: 30-40 minutes
  Total Round Trip: ~50 minutes
```

### 8. Slow Stake Execution - Native ETH (`slowStakeNativeExample.ts`)

Executes complete cross-chain liquid staking using only native ETH.

**What it does**:

- Creates CCIP message for cross-chain execution
- Pays all fees (staking + CCIP + bridge) in native ETH
- Provides comprehensive tracking instructions
- Monitors complete O→D→O journey

**Use case**: Cross-chain staking with simple single-token payment

**Sample output**:

```
🐌 SlowStake with Native ETH on Base
📱 Using wallet: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
💰 Staking amount: 0.001 ETH
🔗 CCIP fee payment: native ETH

🎉 SlowStake Transaction Successful!
📊 Transaction Details:
  TX Hash: 0x4aa7d4e4ff650febe32aec89b3132efc582d7d30e42343ec1c99d1ac2dfe67e2
  Message ID: 0x3e44ae54221139386ca4e22bcfe6600b7d47bc6af446e72ad549ede0a9a2c752

📍 How to Track Your Cross-Chain Transaction:
🔗 Step 1: Track CCIP Message (Origin → Destination)
   Monitor: https://ccip.chain.link/msg/0x3e44ae54221139386ca4e22bcfe6600b7d47bc6af446e72ad549ede0a9a2c752
   Wait for status to show "Success" (usually 10-20 minutes)

🏛️ Step 2: Verify Ethereum Execution
   Once CCIP shows "Success", click "View on Destination Chain"
   Look for "BaseL1toL2MessageSent" event in the transaction logs

🔄 Step 3: Wait for Return Bridge (Destination → Origin)
   The canonical bridge will deliver wstETH back to you
   This usually takes 30-40 additional minutes
```

### 9. Slow Stake Execution - Native + LINK (`slowStakeNativeLinkExample.ts`)

Executes cross-chain staking with native ETH for staking and LINK for CCIP fees.

**What it does**:

- Uses native ETH for staking (simple, no conversion needed)
- Pays CCIP fees with LINK tokens (potentially lower costs)
- Manages LINK allowances automatically
- Demonstrates cost optimization approach
- Provides detailed fee structure analysis

**Use case**: Cross-chain staking with simple native staking but optimized CCIP costs

**Key features**:

- Native ETH for staking amount (no allowance needed)
- LINK for CCIP fees (potential cost savings)
- ETH for bridge fees (standard)
- Single allowance management (LINK only)
- Comprehensive balance checking for both tokens

**Sample output**:

```
🐌 SlowStake with Native ETH + LINK CCIP on Base
📱 Using wallet: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
💰 Staking amount: 0.001 ETH
🔗 CCIP fee payment: LINK tokens

💰 Checking token balances...
✅ ETH balance sufficient: 0.03121606974466467 ETH (required: 0.001 ETH)
✅ LINK balance sufficient: 2.0 LINK (required: 0.803772622769855162 LINK)

🎉 SlowStake Transaction Successful!
📊 Transaction Details:
  TX Hash: 0x8719c9332a04ac003a8d98a68d62b6df20ac2754996c6b612c548f25283bed41
  Message ID: 0x11b0de23d60abda8d8c600885016191ca0efa36cc0791e68147f51e93b71c7cb

💰 Fee Structure Analysis:
  Staking Amount: 0.001 ETH
  CCIP Fee (O→D): 0.803772622769855162 LINK
  Bridge Fee (D→O): 0.0 ETH

💡 Cost Comparison:
  This Method (Native ETH + LINK):
    ETH: 0.001 ETH (staking) + 0.0 ETH (bridge)
    LINK: 0.803772622769855162 LINK (CCIP fees)
  Alternative (All Native ETH): Would require 0 LINK but higher ETH costs
  Alternative (WETH + LINK): Would require WETH approval and conversion
```

### 10. Slow Stake Execution - Wrapped + Native (`slowStakeWrappedNativeExample.ts`)

Executes cross-chain staking with WETH for staking and native ETH for CCIP fees.

**What it does**:

- Uses WETH for precise staking amount
- Pays CCIP fees with native ETH for simplicity
- Manages WETH allowances automatically
- Demonstrates hybrid payment approach
- Provides detailed cross-chain tracking

**Use case**: Cross-chain staking with wrapped tokens but simplified fee payment

**Key features**:

- WETH for staking amount (precise, no conversion)
- Native ETH for CCIP fees (no allowance needed)
- ETH for bridge fees (standard)
- Single allowance management (WETH only)
- Comprehensive cross-chain monitoring

**Sample output**:

```
🐌 SlowStake with Wrapped Native + Native CCIP on Base
📱 Using wallet: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
💰 Staking amount: 0.0001 WETH
🔗 CCIP fee payment: NATIVE ETH

💰 Checking token balances...
✅ ETH balance sufficient: 0.034750654117750253 ETH (required: 0.004341398653008682 ETH)
✅ WETH balance sufficient: 0.0005 WETH (required: 0.0001 WETH)

🎉 SlowStake Transaction Successful!
📊 Transaction Details:
  TX Hash: 0x95c75479092391fb8718d964ee2d0f0773f83e63bd29ad4d6738b98627348b35
  Message ID: 0x98666a1786fc2eb7cfef03507d62a02e79d3b799b08be61026d979f52e01bfdc

📋 Contract Call Details:
  Token: 0x4200000000000000000000000000000000000006 (WETH)
  Amount: 0.0001 WETH
  Total ETH Value: 0.004341398653008682 ETH (CCIP + bridge fees)

💰 Fee Structure Analysis:
  Staking Amount: 0.0001 WETH
  CCIP Fee (O→D): 0.004241398653008682 ETH
  Bridge Fee (D→O): 0.0 ETH

💡 Cost Comparison:
  This Method (WETH + Native CCIP):
    WETH: 0.0001 WETH
    ETH: 0.004341398653008682 ETH
  Alternative (All Native ETH): Would require 0.004341398653008682 ETH total
  Alternative (WETH + LINK): Would require WETH + LINK + bridge ETH
```

### 11. Slow Stake Execution - Wrapped + LINK (`slowStakeWrappedLinkExample.ts`)

Executes cross-chain staking with WETH for staking and LINK for CCIP fees.

**What it does**:

- Manages dual-token allowances (WETH + LINK)
- Splits fee payments across multiple tokens
- Demonstrates complex cross-chain coordination
- Provides detailed tracking for multi-token flows

**Use case**: Advanced cross-chain staking with optimized fee payments

**Key features**:

- WETH for staking amount (precise, no conversion)
- LINK for CCIP fees (potential cost savings)
- ETH for bridge fees (standard)
- Dual allowance management (WETH + LINK)
- Comprehensive balance checking for all three tokens

**Sample output**:

```
🐌 SlowStake with Wrapped Native + LINK on Base
📱 Using wallet: 0x2Ae947aDC044091EE1b8D4FB8262308C6A4F34E0
💰 Staking amount: 0.0001 WETH
🔗 CCIP fee payment: LINK tokens

💰 Checking token balances...
✅ ETH balance sufficient: 0.030215541974439636 ETH (required: 0.0001 ETH)
✅ WETH balance sufficient: 0.0004 WETH (required: 0.0001 WETH)
✅ LINK balance sufficient: 1.330269620430506932 LINK (required: 0.803772622769855162 LINK)

🎉 SlowStake Transaction Successful!
📊 Transaction Details:
  TX Hash: 0x3fcbd84718d85c7c39daf9b05f9d9370b4112af7afeae4c19e8e562581bca8aa
  Message ID: 0x09fe306b48af4c02a0cdd940a6b29547c16a34c753a3be6eec434d5b594b6c7f

🔐 Allowance Management Summary:
  WETH Allowances:
    Initial: Unlimited (MaxUint256)
    ✅ Sufficient Allowance Existed
  LINK Allowances:
    Initial: Unlimited (MaxUint256)
    ✅ Sufficient Allowance Existed

💰 Fee Structure Analysis:
  Staking Amount: 0.0001 WETH
  CCIP Fee (O→D): 0.803772622769855162 LINK
  Bridge Fee (D→O): 0.0 ETH

💡 Cost Comparison:
  This Method (WETH + LINK):
    WETH: 0.0001 WETH
    LINK: 0.803772622769855162 LINK
    ETH: 0.0001 ETH
  Alternative (All Native ETH): Would require 0.803872622769855162 ETH total
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

### Fast Stake Components

**CustomSender**: Entry point for both fast and slow stake operations
**OraclePool**: Manages WETH ↔ wstETH swaps and maintains liquidity
**PriceOracle**: Chainlink price feed providing wstETH/WETH exchange rates
**Tokens**: WETH (input) and wstETH (output) token contracts

### Slow Stake Components

**CCIP Router**: Chainlink cross-chain infrastructure for O→D messaging
**Bridge Adapters**: Protocol-specific bridges for D→O return (Base, Arbitrum, Optimism)
**Fee Codecs**: Encoding/decoding for complex multi-chain fee structures
**Receiver Contracts**: Ethereum contracts handling staking and return bridging

## Pool Mechanics

1. **Fast Stakes**: Users deposit WETH and receive wstETH immediately from pool reserves
2. **Pool Sync**: Accumulated WETH is periodically staked on L1 Ethereum to mint new wstETH
3. **Liquidity**: Pool maintains wstETH reserves for instant swaps
4. **Fees**: Currently 0% for Lido pools (configurable per pool)

## Cross-Chain Mechanics (Slow Stake)

1. **Origin → Destination (O→D)**: ETH/WETH sent to Ethereum via Chainlink CCIP (~10-20 min)
2. **L1 Staking**: On Ethereum, ETH is staked with Lido to receive stETH, then wrapped to wstETH
3. **Destination → Origin (D→O)**: wstETH bridged back via canonical bridges (~30-40 min)
4. **Fee Structure**:
   - CCIP fees (paid in ETH or LINK)
   - Bridge fees (usually ETH, varies by destination chain)
   - No protocol fees for slow staking
5. **Tracking**: Full transparency via CCIP Explorer and bridge monitoring

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

### General Setup

1. **Set up environment**: Create `.env` file with `PRIVATE_KEY=your_private_key_here` for automatic wallet usage
2. **Choose staking method**: Fast stake for speed (when liquidity available), slow stake for reliability (always works)
3. **Test small amounts**: Start with small stakes (0.01 ETH) for testing

### Fast Stake Tips

4. **Check liquidity first**: Use pool balance queries before large transactions
5. **Monitor pool health**: High WETH ratios indicate pools need sync operations
6. **Set slippage tolerance**: 1-3% typical for stable conditions, higher during volatility
7. **Handle rate changes**: Oracle rates update daily and may fluctuate

### Slow Stake Tips

8. **Estimate fees first**: Use slow stake estimation to understand total costs (~3-5x staking amount)
9. **Choose fee payment method**:
   - Native ETH + Native ETH: Simplest approach, one token type
   - Native ETH + LINK: Simple staking, potentially lower CCIP costs
   - WETH + Native ETH: Precise staking amount, simple fees
   - WETH + LINK: Maximum precision, potentially lowest costs, most complex
10. **Track with CCIP Explorer**: Monitor progress at https://ccip.chain.link/msg/{messageId}
11. **Expect ~50 minute total time**: Plan for 10-20 min O→D + 30-40 min D→O
12. **Verify allowances**: WETH needs approval for wrapped variants, LINK needs approval for LINK fee payment

### Common to Both

13. **Choose payment method**: Native ETH for simplicity, wrapped tokens for precision
14. **Use Base for testing**: Generally has good liquidity and lower gas costs
15. **Factor gas costs**: Consider L2 transaction costs and approval overhead

## Common Issues

### Fast Stake Issues

**Insufficient liquidity**: Pool may not have enough wstETH for large swaps
**Stale oracle data**: Check heartbeat to ensure recent price updates
**High slippage**: Transaction fails if actual rate exceeds minAmountOut

### Slow Stake Issues

**High CCIP fees**: Cross-chain fees can be 3-5x the staking amount
**CCIP message failures**: Check CCIP Explorer if transaction doesn't appear
**Bridge delays**: D→O return can take longer during network congestion
**Insufficient LINK**: Ensure adequate LINK balance for CCIP fee payments
**Multiple allowances needed**: Both WETH and LINK require approvals

### General Issues

**Insufficient allowance**: Token operations require approval first
**Gas estimation errors**: Network congestion can cause gas estimation failures
**Private key missing**: Execution examples require PRIVATE_KEY environment variable
**RPC rate limits**: Use dedicated RPC providers for production usage
**Network differences**: Each chain has different pool liquidity and fee levels

## External Resources

- [Lido Protocol](https://lido.fi)
- [Lido Documentation](https://docs.lido.fi)
- [wstETH Guide](https://help.lido.fi/en/articles/5230610-what-is-wrapped-steth-wsteth)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
