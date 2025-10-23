# Allowance API Reference

ERC20 token allowance management for liquid staking operations. These functions help check and manage token approvals required for wrapped token operations.

## Overview

When using wrapped tokens (like WETH), users must first approve the spending contract to transfer tokens on their behalf. This API provides utilities to:

1. **Check current allowances** for a user
2. **Validate approval status** before transactions
3. **Get token metadata** and balances
4. **Provide actionable guidance** for approvals

## Functions

- [`checkTokenAllowance()`](#checktokenallowance) - Check ERC20 token allowance for liquid staking operations

---

## `checkTokenAllowance()`

Checks the current ERC20 token allowance for a user address against the liquid staking contracts. Provides comprehensive allowance status and token information.

### Function Signature

```typescript
function checkTokenAllowance(params: CheckTokenAllowanceParams): Promise<CheckTokenAllowanceResult>;
```

### Parameters

```typescript
interface CheckTokenAllowanceParams {
  /** Supported chain ID for operations */
  chainKey: SupportedChainId;
  /** User address to check allowance for */
  userAddress: Address;
  /** Protocol configuration to use */
  protocol: ProtocolConfig;
}
```

### Returns

```typescript
interface CheckTokenAllowanceResult {
  /** Complete allowance information */
  readonly allowanceInfo: TokenAllowanceInfo;

  /** Contract addresses for reference */
  readonly contracts: {
    readonly customSender: Address;
    readonly oraclePool: Address;
    readonly priceOracle: Address;
    readonly wnative: Address;
    readonly linkToken: Address;
  };

  /** Chain and protocol information */
  readonly metadata: {
    readonly chainKey: SupportedChainId;
    readonly protocolName: string;
  };
}
```

#### Return Type Details

```typescript
interface TokenAllowanceInfo {
  /** TOKEN contract information */
  readonly token: TokenInfo;
  /** TOKEN address (same as token.address for clarity) */
  readonly tokenAddress: Address;
  /** CustomSender contract address (spender) */
  readonly spenderAddress: Address;
  /** User's current allowance in wei */
  readonly allowance: bigint;
  /** Whether user has unlimited allowance (max uint256) */
  readonly hasUnlimitedAllowance: boolean;
  /** Whether user has any allowance (> 0) */
  readonly hasAllowance: boolean;
  /** User's token balance in wei */
  readonly userBalance: bigint;
}

interface TokenInfo {
  readonly address: Address;
  readonly symbol: string; // e.g., 'WETH'
  readonly name: string; // e.g., 'Wrapped Ether'
  readonly decimals: number; // Usually 18
}
```

### Token Resolution

The function automatically determines the correct token:

1. **Queries CustomSender contract** for the immutable `TOKEN` field
2. **Resolves to the staking token** (typically WETH on most chains)
3. **Fetches complete metadata** including symbol, name, and decimals

### Usage Example

```typescript
import { checkTokenAllowance, LIDO_PROTOCOL } from '@chainlink/csr-offchain';
import { formatEther } from 'ethers';

const allowanceInfo = await checkTokenAllowance({
  chainKey: 'BASE_MAINNET',
  userAddress: '0x742d35Cc...',
  protocol: LIDO_PROTOCOL,
});

const { allowanceInfo: info } = allowanceInfo;

console.log(`Token: ${info.token.symbol} (${info.token.name})`);
console.log(`User Balance: ${formatEther(info.userBalance)} ${info.token.symbol}`);
console.log(`Current Allowance: ${formatEther(info.allowance)} ${info.token.symbol}`);

if (info.hasUnlimitedAllowance) {
  console.log('✅ Unlimited allowance approved');
} else if (info.hasAllowance) {
  console.log('⚠️ Limited allowance approved');
} else {
  console.log('❌ No allowance - approval required');
}
```

### Allowance Status Checking

```typescript
const result = await checkTokenAllowance(params);
const { allowanceInfo } = result;

// Check if user needs to approve for a specific amount
const requiredAmount = parseEther('1.0');

if (allowanceInfo.allowance < requiredAmount) {
  console.log('🔒 Approval Required');
  console.log(`Current: ${formatEther(allowanceInfo.allowance)} ${allowanceInfo.token.symbol}`);
  console.log(`Required: ${formatEther(requiredAmount)} ${allowanceInfo.token.symbol}`);
  console.log(
    `Shortfall: ${formatEther(requiredAmount - allowanceInfo.allowance)} ${allowanceInfo.token.symbol}`
  );

  // Provide contract addresses for approval
  console.log(`Approve: ${allowanceInfo.spenderAddress}`);
} else {
  console.log('✅ Sufficient allowance available');
}
```

### Multi-Chain Allowance Checking

```typescript
import { SUPPORTED_CHAINS } from '@chainlink/csr-offchain';

async function checkAllowancesAcrossChains(userAddress: Address) {
  const results = await Promise.all(
    SUPPORTED_CHAINS.map(async chainKey => {
      try {
        const result = await checkTokenAllowance({
          chainKey,
          userAddress,
          protocol: LIDO_PROTOCOL,
        });
        return { chainKey, result, error: null };
      } catch (error) {
        return { chainKey, result: null, error };
      }
    })
  );

  // Process results
  results.forEach(({ chainKey, result, error }) => {
    if (error) {
      console.log(`${chainKey}: Error - ${error.message}`);
    } else if (result) {
      const { allowanceInfo } = result;
      console.log(
        `${chainKey}: ${allowanceInfo.token.symbol} allowance: ${formatEther(allowanceInfo.allowance)}`
      );
    }
  });
}
```

### Approval Guidance

```typescript
function generateApprovalGuidance(allowanceInfo: TokenAllowanceInfo, requiredAmount: bigint) {
  if (allowanceInfo.allowance >= requiredAmount) {
    return {
      approvalNeeded: false,
      message: '✅ Sufficient allowance already exists',
    };
  }

  const recommendations = [];

  // Check if user has sufficient balance
  if (allowanceInfo.userBalance < requiredAmount) {
    recommendations.push(`⚠️ Insufficient ${allowanceInfo.token.symbol} balance`);
    recommendations.push(`Need: ${formatEther(requiredAmount)} ${allowanceInfo.token.symbol}`);
    recommendations.push(
      `Available: ${formatEther(allowanceInfo.userBalance)} ${allowanceInfo.token.symbol}`
    );
  }

  // Approval options
  recommendations.push('📝 Approval Options:');
  recommendations.push(
    `1. Approve exact amount: ${formatEther(requiredAmount)} ${allowanceInfo.token.symbol}`
  );
  recommendations.push(`2. Approve unlimited (saves gas on future transactions)`);

  // Contract interaction
  recommendations.push('🔧 Contract Interaction:');
  recommendations.push(`Token Contract: ${allowanceInfo.tokenAddress}`);
  recommendations.push(`Spender (CustomSender): ${allowanceInfo.spenderAddress}`);

  return {
    approvalNeeded: true,
    message: recommendations.join('\n'),
  };
}

// Usage
const guidance = generateApprovalGuidance(allowanceInfo.allowanceInfo, parseEther('1.0'));
console.log(guidance.message);
```

### Integration with Transaction Flows

```typescript
// Pre-transaction allowance validation
async function validateAllowanceForTransaction(params: {
  chainKey: SupportedChainId;
  userAddress: Address;
  requiredAmount: bigint;
  protocol: ProtocolConfig;
}) {
  const allowanceResult = await checkTokenAllowance({
    chainKey: params.chainKey,
    userAddress: params.userAddress,
    protocol: params.protocol,
  });

  const { allowanceInfo } = allowanceResult;

  // Validate balance
  if (allowanceInfo.userBalance < params.requiredAmount) {
    throw new Error(`Insufficient ${allowanceInfo.token.symbol} balance`);
  }

  // Validate allowance
  if (allowanceInfo.allowance < params.requiredAmount) {
    throw new Error(
      `Insufficient ${allowanceInfo.token.symbol} allowance. Please approve ${formatEther(params.requiredAmount)} ${allowanceInfo.token.symbol} to ${allowanceInfo.spenderAddress}`
    );
  }

  return allowanceResult;
}

// Use in transaction preparation
try {
  await validateAllowanceForTransaction({
    chainKey: 'BASE_MAINNET',
    userAddress: wallet.address,
    requiredAmount: parseEther('1.0'),
    protocol: LIDO_PROTOCOL,
  });

  // Proceed with transaction
} catch (error) {
  console.error('Pre-transaction validation failed:', error.message);
  // Handle approval requirements
}
```

### Errors

| Error                               | When                      | Resolution                |
| ----------------------------------- | ------------------------- | ------------------------- |
| `Protocol not supported on {chain}` | Invalid chainKey/protocol | Use supported combination |
| `Contract not found`                | Deployment issues         | Verify contract addresses |
| `Token metadata fetch failed`       | RPC connectivity          | Check RPC endpoints       |
| `Invalid user address`              | Malformed address         | Verify address format     |

### Common Error Handling

```typescript
try {
  const result = await checkTokenAllowance(params);
  // Process result
} catch (error) {
  if (error.message.includes('not supported')) {
    console.error('Chain/protocol not supported:', error.message);
  } else if (error.message.includes('Contract not found')) {
    console.error('Deployment issue:', error.message);
  } else if (error.message.includes('metadata fetch failed')) {
    console.error('RPC connectivity issue:', error.message);
  } else {
    console.error('Unexpected error:', error.message);
  }
}
```

## Token Approval Workflow

### Manual Approval Process

```typescript
import { MaxUint256 } from 'ethers';

// 1. Check current allowance
const allowanceResult = await checkTokenAllowance(params);
const { allowanceInfo } = allowanceResult;

// 2. Determine approval amount
const requiredAmount = parseEther('1.0');
const approveAmount = allowanceInfo.hasUnlimitedAllowance
  ? allowanceInfo.allowance // Keep existing unlimited
  : MaxUint256; // Approve unlimited for convenience

// 3. Execute approval (pseudo-code)
if (allowanceInfo.allowance < requiredAmount) {
  const tokenContract = new Contract(allowanceInfo.tokenAddress, ERC20_ABI, signer);
  const approveTx = await tokenContract.approve(allowanceInfo.spenderAddress, approveAmount);
  await approveTx.wait();

  console.log(`✅ Approved ${formatEther(approveAmount)} ${allowanceInfo.token.symbol}`);
}
```

### Automated Approval Integration

```typescript
// Integration pattern used by execution functions
async function ensureSufficientAllowance(
  params: CheckTokenAllowanceParams & {
    requiredAmount: bigint;
    signer: Signer;
    autoApproveUnlimited?: boolean;
  }
) {
  const allowanceResult = await checkTokenAllowance(params);
  const { allowanceInfo } = allowanceResult;

  if (allowanceInfo.allowance < params.requiredAmount) {
    const approveAmount = params.autoApproveUnlimited ? MaxUint256 : params.requiredAmount;

    // Execute approval transaction
    const tokenContract = new Contract(
      allowanceInfo.tokenAddress,
      ['function approve(address spender, uint256 amount) returns (bool)'],
      params.signer
    );

    const tx = await tokenContract.approve(allowanceInfo.spenderAddress, approveAmount);
    await tx.wait();

    return { ...allowanceResult, approvalExecuted: true, approvalTxHash: tx.hash };
  }

  return { ...allowanceResult, approvalExecuted: false };
}
```

## Related APIs

- **[Fast Stake API](../fastStake/README.md)** - Uses allowances for wrapped token fast stakes
- **[Slow Stake API](../slowStake/README.md)** - Handles dual allowances (WETH + LINK)
- **[Pool API](../pool/README.md)** - Pool operations may require allowances

## Integration Examples

For complete integration examples, see:

- **[Allowance Examples](../../examples/lido/README.md#allowance-checking)** - Comprehensive allowance checking
- **[Execution Examples](../../examples/lido/README.md)** - Automatic allowance management in transactions
