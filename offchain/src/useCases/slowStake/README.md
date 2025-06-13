# Slow Stake API Reference

Cross-chain liquid staking operations via Chainlink CCIP. These functions enable staking on Layer 2 networks with execution on Ethereum mainnet.

## Overview

Slow stake operations involve a multi-step cross-chain process:

1. **Origin → Destination (O→D)**: Send tokens to Ethereum via CCIP (~10-20 minutes)
2. **L1 Execution**: Stake tokens on Ethereum mainnet
3. **Destination → Origin (D→O)**: Bridge staked tokens back (~30-40 minutes)

**Total time**: ~50 minutes for complete round-trip

## Functions

- [`estimateSlowStakeFees()`](#estimateslowstakefees) - Calculate comprehensive fee breakdown
- [`executeSlowStake()`](#executeslowstake) - Execute cross-chain staking with allowance management
- [`validateSlowStakeExecution()`](#validateslowstakeexecution) - Dry-run validation without sending transactions
- [`estimateAndExecuteSlowStake()`](#estimateandexecuteslowstake) - Combined estimation and execution
- [`checkSufficientBalance()`](#checksufficientbalance) - Validate user has required balances

---

## `estimateSlowStakeFees()`

Calculates comprehensive fee breakdown for cross-chain slow stake operations including CCIP fees, bridge fees, and token requirements.

### Function Signature

```typescript
function estimateSlowStakeFees(
  params: EstimateSlowStakeFeesParams
): Promise<SlowStakeFeeEstimation>;
```

### Parameters

```typescript
interface EstimateSlowStakeFeesParams {
  /** Supported chain ID for operations */
  chainKey: SupportedChainId;
  /** Amount to stake, in wei */
  stakingAmount: bigint;
  /** Payment method for staking: 'native' for ETH, 'wrapped' for WETH */
  paymentMethod: PaymentMethod;
  /** Fee payment method for CCIP: 'native' for ETH, 'link' for LINK token */
  ccipFeePaymentMethod: CCIPFeePaymentMethod;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
}
```

### Returns

```typescript
interface SlowStakeFeeEstimation {
  readonly stakingAmount: bigint;
  readonly paymentMethod: PaymentMethod;
  readonly ccipFeePaymentMethod: CCIPFeePaymentMethod;

  // Fee breakdowns with encoded data
  readonly feeOtoD: CCIPFeeEstimation; // Origin → Destination fees
  readonly feeDtoO: BridgeFeeEstimation; // Destination → Origin fees

  // Token requirements
  readonly requirements: {
    readonly ethRequired: bigint; // ETH needed (staking + bridge fees)
    readonly linkRequired: bigint; // LINK needed (0 if paying with ETH)
  };

  // Contract addresses
  readonly contracts: {
    readonly customSender: string;
    readonly linkToken: string;
    readonly wnative: string;
    readonly ccipRouter: string;
  };

  // Human-readable summary
  readonly summary: {
    readonly stakingAmountFormatted: string;
    readonly feeOtoDFormatted: string;
    readonly feeOtoDToken: string; // 'ETH' or 'LINK'
    readonly feeDtoOFormatted: string;
    readonly ethRequiredFormatted: string;
    readonly linkRequiredFormatted: string;
  };
}
```

### Usage Example

```typescript
import { estimateSlowStakeFees, LIDO_PROTOCOL } from '@chainlink/csr-offchain';
import { parseEther } from 'ethers';

const fees = await estimateSlowStakeFees({
  chainKey: 'BASE_MAINNET',
  stakingAmount: parseEther('1.0'),
  paymentMethod: 'native',
  ccipFeePaymentMethod: 'link',
  protocol: LIDO_PROTOCOL,
});

console.log(`Total ETH required: ${fees.summary.ethRequiredFormatted} ETH`);
console.log(`Total LINK required: ${fees.summary.linkRequiredFormatted} LINK`);
```

### Errors

| Error                                | When                    | Resolution                   |
| ------------------------------------ | ----------------------- | ---------------------------- |
| `SlowStake not supported on {chain}` | Invalid chainKey        | Use supported L2 chain       |
| `Protocol not supported`             | Invalid protocol config | Check protocol configuration |
| `CCIP router not found`              | Contract setup issue    | Verify contract deployment   |

---

## `executeSlowStake()`

Executes a complete slow stake operation with automatic fee estimation, balance checking, allowance management, and transaction execution.

### Function Signature

```typescript
function executeSlowStake(params: ExecuteSlowStakeParams): Promise<SlowStakeExecutionResult>;
```

### Parameters

```typescript
interface ExecuteSlowStakeParams {
  /** Supported chain ID for operations */
  chainKey: SupportedChainId;
  /** Amount to stake, in wei */
  stakingAmount: bigint;
  /** Payment method for staking: 'native' for ETH, 'wrapped' for WETH */
  paymentMethod: PaymentMethod;
  /** Fee payment method for CCIP: 'native' for ETH, 'link' for LINK token */
  ccipFeePaymentMethod: CCIPFeePaymentMethod;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
  /** Signer to execute the transaction */
  signer: Signer;
  /** Optional recipient address (defaults to signer address) */
  recipient?: string;
  /** Whether to use pre-calculated fee estimation (optional optimization) */
  feeEstimation?: SlowStakeFeeEstimation;
  /** Whether to auto-approve unlimited allowance for tokens (default: false) */
  autoApproveUnlimited?: boolean;
}
```

### Returns

```typescript
interface SlowStakeExecutionResult {
  readonly transactionHash: string;
  readonly messageId: string; // CCIP message ID for tracking
  readonly feeEstimation: SlowStakeFeeEstimation;

  // Allowance management details
  readonly allowanceManagement: AllowanceManagementInfo;

  // Decoded event information
  readonly slowStakeEvent: SlowStakeEventInfo;

  // Contract call details
  readonly contractCall: {
    readonly destChainSelector: string;
    readonly token: string;
    readonly amount: bigint;
    readonly feeOtoD: string; // Encoded CCIP fee data
    readonly feeDtoO: string; // Encoded bridge fee data
    readonly totalValue: bigint; // Total ETH sent with transaction
  };
}
```

### Execution Flow

1. **Balance Checking**: Validates sufficient ETH, WETH, and LINK balances
2. **Allowance Management**: Automatically approves WETH and/or LINK if needed
3. **Transaction Execution**: Calls `slowStake()` contract function
4. **Event Parsing**: Extracts CCIP message ID and transaction details
5. **Result Compilation**: Returns comprehensive execution information

### Usage Example

```typescript
import { executeSlowStake, LIDO_PROTOCOL } from '@chainlink/csr-offchain';
import { parseEther } from 'ethers';

const result = await executeSlowStake({
  chainKey: 'BASE_MAINNET',
  stakingAmount: parseEther('1.0'),
  paymentMethod: 'wrapped',
  ccipFeePaymentMethod: 'link',
  protocol: LIDO_PROTOCOL,
  signer: wallet,
  autoApproveUnlimited: true,
});

console.log(`Transaction: ${result.transactionHash}`);
console.log(`Track CCIP: https://ccip.chain.link/msg/${result.messageId}`);
```

### Errors

| Error                            | When                      | Resolution                    |
| -------------------------------- | ------------------------- | ----------------------------- |
| `Insufficient {token} balance`   | Not enough tokens         | Add funds to wallet           |
| `execution reverted`             | Contract execution failed | Check parameters and balances |
| `Transaction failed: no receipt` | Network issues            | Retry transaction             |

---

## `validateSlowStakeExecution()`

Performs a dry-run validation of slow stake parameters without sending a transaction. Useful for parameter validation and gas estimation.

### Function Signature

```typescript
function validateSlowStakeExecution(params: ExecuteSlowStakeParams): Promise<{
  valid: boolean;
  estimatedGas?: bigint;
  feeEstimation: SlowStakeFeeEstimation;
  error?: string;
}>;
```

### Parameters

Same as [`executeSlowStake()`](#executeslowstake) - accepts all execution parameters.

### Returns

```typescript
interface ValidationResult {
  readonly valid: boolean;
  readonly estimatedGas?: bigint; // Gas estimate if valid
  readonly feeEstimation: SlowStakeFeeEstimation;
  readonly error?: string; // Error message if invalid
}
```

### Usage Example

```typescript
const validation = await validateSlowStakeExecution({
  chainKey: 'BASE_MAINNET',
  stakingAmount: parseEther('1.0'),
  paymentMethod: 'native',
  ccipFeePaymentMethod: 'native',
  protocol: LIDO_PROTOCOL,
  signer: wallet,
});

if (validation.valid) {
  console.log(`Estimated gas: ${validation.estimatedGas}`);
  // Proceed with actual execution
} else {
  console.error(`Validation failed: ${validation.error}`);
}
```

---

## `estimateAndExecuteSlowStake()`

Convenience function that combines fee estimation and execution in a single call.

### Function Signature

```typescript
function estimateAndExecuteSlowStake(
  params: Omit<ExecuteSlowStakeParams, 'feeEstimation'>
): Promise<SlowStakeExecutionResult>;
```

### Parameters

Same as [`executeSlowStake()`](#executeslowstake) except `feeEstimation` is automatically calculated.

### Usage Example

```typescript
// Equivalent to estimating then executing
const result = await estimateAndExecuteSlowStake({
  chainKey: 'BASE_MAINNET',
  stakingAmount: parseEther('1.0'),
  paymentMethod: 'native',
  ccipFeePaymentMethod: 'native',
  protocol: LIDO_PROTOCOL,
  signer: wallet,
});
```

---

## `checkSufficientBalance()`

Utility function to check if the signer has sufficient native token balance for the operation.

### Function Signature

```typescript
function checkSufficientBalance(
  params: Pick<
    ExecuteSlowStakeParams,
    'chainKey' | 'stakingAmount' | 'paymentMethod' | 'ccipFeePaymentMethod' | 'protocol' | 'signer'
  >
): Promise<{
  sufficient: boolean;
  required: bigint;
  available: bigint;
  shortfall?: bigint;
}>;
```

### Usage Example

```typescript
const balanceCheck = await checkSufficientBalance({
  chainKey: 'BASE_MAINNET',
  stakingAmount: parseEther('1.0'),
  paymentMethod: 'native',
  ccipFeePaymentMethod: 'native',
  protocol: LIDO_PROTOCOL,
  signer: wallet,
});

if (!balanceCheck.sufficient) {
  console.log(`Need ${formatEther(balanceCheck.shortfall)} more ETH`);
}
```

## Payment Method Combinations

| Staking    | CCIP Fees  | Complexity   | Allowances  | Use Case                |
| ---------- | ---------- | ------------ | ----------- | ----------------------- |
| Native ETH | Native ETH | **Simplest** | None        | One-token approach      |
| Native ETH | LINK       | **Low**      | LINK only   | Cost optimization       |
| WETH       | Native ETH | **Medium**   | WETH only   | Precision + simple fees |
| WETH       | LINK       | **Highest**  | WETH + LINK | Maximum optimization    |

## Error Handling

### Common Errors

```typescript
try {
  const result = await executeSlowStake(params);
} catch (error) {
  if (error.message.includes('Insufficient')) {
    // Handle balance issues
    console.error('Insufficient funds:', error.message);
  } else if (error.message.includes('not supported')) {
    // Handle unsupported chain/protocol
    console.error('Configuration error:', error.message);
  } else if (error.message.includes('execution reverted')) {
    // Handle contract execution failures
    console.error('Transaction failed:', error.message);
  } else {
    // Handle unexpected errors
    console.error('Unexpected error:', error.message);
  }
}
```

### Balance Validation Pattern

```typescript
// Check balances before execution
const balanceCheck = await checkSufficientBalance(params);
if (!balanceCheck.sufficient) {
  throw new Error(`Insufficient balance: need ${balanceCheck.shortfall} more`);
}

// Proceed with execution
const result = await executeSlowStake(params);
```

## Related APIs

- **[Fast Stake API](../fastStake/README.md)** - For instant swaps when liquidity is available
- **[Allowance API](../allowance/README.md)** - For advanced allowance management
- **[Pool API](../pool/README.md)** - For checking liquidity before operations

## Integration Examples

For complete integration examples, see:

- **[Slow Stake Examples](../../examples/lido/README.md#slow-stake-execution)** - All four payment combinations
- **[Tutorial Examples](../../examples/README.md)** - Step-by-step implementation guides
