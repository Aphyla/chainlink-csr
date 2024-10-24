# ChainLink Custom Sender-Receiver

The ChainLink Custom Sender-Receiver is a set of smart contracts that allow users to stake a token on a L2 and receive the L1 native token directly on the L2 chain. For example, a user can stake (W)ETH on Arbitrum or Optimism and receive wstETH directly on the same chain.

## Fast Stake

The `fastStake` function from the [CustomSender](contracts/senders/CustomSender.sol) contract can be used to use a [OraclePool](contracts/utils/OraclePool.sol) to swap (W)ETH for a Liquid Staked Token (LST) on the same chain using an exchange rate oracle.
The (W)ETH that accumulates in the pool can be sent to the L1 chain to mint the LST using the `sync` function from the [CustomSender](contracts/senders/CustomSender.sol) contract. The (W)ETH will be sent to the [CustomReceiver](contracts/receivers/CustomReceiver.sol) contract on the L1 chain that will mint the LST and send it back to the pool on the L2 chain.

![alt text](images/fast_stake.png)

## Slow Stake

The `slowStake` function from the [CustomSender](contracts/senders/CustomSender.sol) contract can be used to send (W)ETH to the [CustomReceiver](contracts/receivers/CustomReceiver.sol) contract on the L1 chain. The (W)ETH sent will be used to mint the LST and send it back to the user on the L2 chain.

![alt text](images/slow_stake.png)

## Key contracts:

[contracts/adapters](contracts/adapters): This folder has adapters for transferring messages/tokens via CCIP and other bridges. If your LST needs a new bridge to be used, you should write a similar adapter.

[contracts/automations/SyncAutomation.sol](contracts/automations/SyncAutomation.sol): CCIP + Chainlink Automation enabled contract to transfer WETH periodically from L2 to L1 (batched transfer with customizable delay parameters). This contract will be the upkeep contract for a Chainlink automation. This contract will also have an option to trigger the token transfer from L2 to L1 outside of the Automation set up. Note: When Chainlink Automation is used to trigger the periodic token transfer, you would need to register a custom logic upkeep and set this contract as the “target contract address” during the registration. This contract needs to be funded with WETH or LINK to pay for the ccip fee (it might also require some WETH to bridge from mainnet to L2, as some bridges requires a fee in WETH). The upkeep needs to be funded for Automation to trigger the performUpkeep based on the trigger conditions.

[contracts/ccip](contracts/ccip): This contains the base contracts for the sender and receiver.

[contracts/libraries/FeeCodec.sol](contracts/libraries/FeeCodec.sol): This implements functions to encode/decode fee related data.

[contracts/receivers](contracts/receivers): Implementation of custom receivers that have the logic to (a) receive the transferred token, (b) perform an action such as staking and (c) transfer the staked token back to the L2. Each project that implements this solution would need to build its own receiver contract using [CustomReceiver.sol](contracts/receivers/CustomReceiver.sol) contract as the base

[contracts/senders/CustomSender.sol](contracts/senders/CustomSender.sol): CCIP sender contract that initiates a programmable token transfer(PTT). In the case of LSTs, it sends WETH along with data attributes necessary for the execution of the logic on the destination chain. The two options described above (fast stake and slow stake) are implemented in this function. The ccipSend functions require encoded fee data values for origin-to-destination (L2-> L1 fee) and destination-to-origin fee (L1->L2 fee), both of which are paid for on the source chain. This contract will also have an option to trigger the token transfer from L2 to L1 outside of the Automation set up via the Sync() function.

[contracts/utils/OraclePool.sol](contracts/utils/OraclePool.sol): A contract that implements a swap of `TOKEN_IN` for `TOKEN_OUT` using a Chainlink exchange rate oracle data feed. It is used by the [CustomSender](contracts/senders/CustomSender.sol) contract to swap `TOKEN_IN` for `TOKEN_OUT` (most of the time, WETH for a LST) during the fast stake process. If you don't wish to offer the fast stake option, you don't have to use this contract and can simply use `0x0` as the `oraclePool` parameter when deploying the [CustomSender](contracts/senders/CustomSender.sol) contract.

## Key parameters to be set for deployment:

#### Custom Sender parameters:

- TOKEN: The underlying token address on the L2 chain
- WNATIVE: The wrapped native token address on the L2 chain
- LINK_TOKEN: The LINK token address on the L2 chain
- CCIP_ROUTER: The CCIP router address on the L2 chain
- ORACLE_POOL: The oracle pool address on the L2 chain (if fast stake is enabled, otherwise set to `0x0`)
- initialAdmin: The initial admin address for the contract that will be granted the `ADMIN_ROLE`

#### Custom Receiver parameters:

- TOKEN: The staked token address on the L1 chain
- WNATIVE: The wrapped native token address on the L1 chain
- CCIP_ROUTER: The CCIP router address on the L1 chain
- initialAdmin: The initial admin address for the contract that will be granted the `ADMIN_ROLE`

Additional parameters might be required depending on the specific implementation of the receiver contract (e.g., the address of the staking contract if it is different from the staked token address).

#### Adapter parameters:

Non-CCIP bridge contracts such as native bridge router contracts/custom bridge contracts

#### Owner:

if the owner should be different from the deployer, update the owner address from address(0) to the actual owner address

#### Origin to Destination Fee parameters: (for example L2 -> L1)

- DESTINATION_MAX_FEE: Max fee used by the CCIP Router when calling sync for the origin to destination fee
- DESTINATION_PAY_IN_LINK: whether the fee should be paid in LINK or WETH
- DESTINATION_GAS_LIMIT: This can be set after estimations during testing ; add a small buffer in case of complex / variable logic on the destination

#### Destination to Origin Fee parameters: (for example L1 -> L2)

Most of the time, bridges have different parameters requirements for the fee.

##### CCIP:

- ORIGIN_MAX_FEE: Max fee used by the CCIP Router when calling sync for the destination to origin fee
- ORIGIN_PAY_IN_LINK: whether the fee should be paid in LINK or WETH
- ORIGIN_GAS_LIMIT: This can be set after estimations during testing ; add a small buffer in case of complex / variable logic on the origin

##### ARBITRUM:

- ORIGIN_MAX_SUBMISSION_COST: The maximum amount of ETH that can be spent on a single transaction
- ORIGIN_MAX_GAS: The maximum amount of gas that can be spent on a single transaction
- ORIGIN_GAS_PRICE_BID: The gas price bid for the transaction

##### OPTIMISM/BASE:

- ORIGIN_L2_GAS: The amount of gas used to cover the L2 execution cost

##### FRAX_FERRY:

- no parameters required

#### Automation Parameters:

- MIN_SYNC_AMOUNT: The minimum amount of ETH required to start the sync process by the automation contract - ie., to make the batching process efficient
- MAX_SYNC_AMOUNT: The maximum amount of ETH that can be bridged in a single transaction by the automation contract, this value needs to be set carefully following the max ETH amount that can be bridged using CCIP and the max ETH fee (as it's also bridged). The capacity and rate limits of ETH transfers can be found on the Supported Networks page for each lane.
- MIN_SYNC_DELAY: The minimum time between syncs by the automation contract, this value should be picked following the time required by the CCIP ETH bucket to refill and the LST/LRT update time.

The automation contract will trigger the sync function in the CustomSender contract every `MIN_SYNC_DELAY` seconds if the balance of the automation contract is greater than `MIN_SYNC_AMOUNT`.

#### Oracle parameters:

- DATAFEED_IS_INVERSE : If the data feed is inverted, i.e. the price returned is the inverse of the price wanted. Note that the price is used by the oracle pool to calculate the amount of TOKEN_OUT to be sent to the user using the formula `amountOut = amountIn * (1e18 - fee) / price`.
- DATAFEED_HEARTBEAT: The maximum time between data feed updates.
- ORACLE_POOL_FEE: If a protocol wishes to charge a fee in the case of a fast stake (The fee to be applied to each swap (in 1e18 scale)).

## How to adapt the contracts to your own LST/LRT

To adapt the contracts for new use case, the following steps need to be taken:

#### Custom Receiver

Implement the `_depositNative` from [CustomReceiver](contracts/receivers/CustomReceiver.sol#L155) and add the logic to mint the LST/LRT from native tokens. For example, wrap the ETH to weth, and then mint the LST/LRT. Don't forget to return the amount of LST/LRT tokens minted.

Note that if the contract implementing the `_depositNative` function requires some values to be set in storage, it is very important to follow the EIP-7201 to prevent storage collisions. It is therefore very important to make sure that the hash used for the storage location is unique. It is highly recommended to use the following hash function to generate the storage location: `keccak256(abi.encode(uint256(keccak256("ccip-csr.storage.<NAME_OF_THE_CONTRACT>")) - 1)) & ~bytes32(uint256(0xff))`.
Do not forget to replace `<NAME_OF_THE_CONTRACT>` with the name of the contract, and that the name used is unique.

#### Bridge Adapter

If the bridge is not supported (currently, only the following bridges are supported: CCIP, Optimism native bridge, Arbitrum Native Bridge, Base native bridge and Frax Ferry), then the protocol needs to inherit the [BridgeAdapter](contracts/adapaters/BridgeAdapter.sol) contract and implement the `_sendToken` function.

Note that bridge adapters should not store any data in storage, as this would lead to storage collisions.

## Frequently Asked Questions / Troubleshooting:

### PROTOCOL OPERATORS:

#### As an operator, what is the routine maintenance I need to take care of?

Keeping the Chainlink upkeep funded:

- The upkeep on automation.chain.link should be funded with enough LINK to perform the necessary upkeeps
- Needs ETH (if using native bridge) in this contract
- Max cost of 1 bridging \* number of transactions expected (depends on the trigger parameters - delay)

Ensuring there are no errors in the `automation` / `performUpkeep` logic.
Refilling bootstrapping liquidity (if needed).

#### How does fee work? What are OtoD and DtoO fees and how should I set them?

At the smart contract level, the [fee codec library](contracts/libraries/FeeCodec.sol) manages encoding and decoding of fees before it is used by the `ccipSend()` or other bridging functions
Important: Front-ends should use the same logic at the front-end layer (ie., using JS libraries) to encode the fee for O->D and D->O fees

##### Origin to Destination : feeOtoD : (L2 -> L1 in this case):

Here, CCIP bridge is used for bridging, CCIP fee can be directly estimated using `getFee()` on the router. and should be encoded using the `encodeCCIP` from the FeeCodec library before being passed into the `ccipSend()` function. A slight buffer should be added to the fee to account for any changes in the fee between the calculation and the execution of the transaction as any excess fee will be refunded to the sender.

##### Destination to Origin: feeDtoO: Other bridges:

- When ARB L1 -> L2 bridge is used, `encodeArbitrumL1toL2` is used. In the case of ARB bridge, there is a certain fee, which can be estimated as follows:
  `feeAmount = maxSubmissionCost + gasPriceBid * maxGas`
  In the case of Automation-based sync for fast stake, the following values were used for testing and worked successfully. However, front-ends are requested to do due diligence to set appropriate values for this based on Arbitrum docs. https://docs.arbitrum.io/how-arbitrum-works/arbos/l1-l2-messaging#submission

  ```solidity
  ARBITRUM_ORIGIN_MAX_SUBMISSION_COST = 0.001e18;
  ARBITRUM_ORIGIN_MAX_GAS = 100_000;
  ARBITRUM_ORIGIN_GAS_PRICE_BID = 0.05e9;
  ```

- When OP L1 -> L2 bridge is used, `encodeOptimismL1toL2` is used passing in the parameter of L2 gas limit. (In the case of OP bridge, fees are 0 at the moment for L1 -> L2). The following value was used for testing and worked successfully. However, the actual gas limit should be set based on the actual gas usage of the transaction.

  ```solidity
  ORIGIN_L2_GAS = 100_000;
  ```

- When BASE L1 -> L2 bridge is used, `encodeBaseL1toL2` is used passing in the parameter of L2 gas limit. (In the case of BASE bridge, fees are 0 at the moment for L1 -> L2). The following value was used for testing and worked successfully. However, the actual gas limit should be set based on the actual gas usage of the transaction.

  ```solidity
  ORIGIN_L2_GAS = 100_000;
  ```

- When Frax bridge L1 -> L2 is used, `encodeFraxFerryL1toL2` is used. In the case of Frax Ferry, fees are 0 at the moment and require no parameters.
- When CCIP bridge is used for bridging from L1 -> L2 (example: for EigenPie), CCIP fee can be directly estimated using `getFee()` on the router. and should be encoded using the `encodeCCIP` before being passed into the `ccipSend()` function. A slight buffer should be added to the fee to account for any changes in the fee between the calculation and the execution of the transaction. Note that any excess fee will be refunded to the sender, which is the custom receiver contract in this case.

#### Can I, as a protocol operator, change the trigger parameters of the automation upkeep?

Yes. The schedule for the upkeep can be updated via the `setDelay` on the [SyncAutomation.sol](contracts/automations/SyncAutomation.sol) contract.
The minimum amount of WETH that needs to be in the OraclePool to initiate a sync as well as the maximum amount of WETH that can be sync’d at a given time can both be updated via the `setAmounts` parameter. Care should be taken to ensure that the max is less than the max pool capacity for WETH transfers via CCIP. The CCIP Supported Networks page provides details on the max capacity for WETH transfers on a given lane. This can also be queried using the `getCurrentOutboundRateLimiterState` function on the WETH pool address. The function returns the max capacity (4th output in the result set) as well as the current capacity (capacity at a given timestamp - 1st output in the result set)

#### As an operator do I need to set up automation jobs for fast staking?

As an operator, there are two ways to batch transfer WETH from L2 to L1 : Automated and manual.

- Automated: We recommend setting up an automation upkeep using Chainlink Automation. Here are the steps:

  1. After the SyncAutomation contract has been deployed, register a custom upkeep using Chainlink Automation.
  2. The SyncAutomation contract should be used as the Target contract for the custom logic upkeep
  3. Fund the upkeep with LINK
  4. The values in your deployment parameters determine the initial values for the trigger conditions ; however this can be changed later using the SyncAutomation contract
  5. The forwarder of the upkeep needs to be assigned a SYNC_ROLE in the CustomSender contract

- Manual: There is also an option to manually trigger a WETH transfer using the sync() function in the CustomSender contract

### FRONT-END OPERATORS:

#### Where do we get the exchange rate to show the user how many LST tokens they will receive for depositing a certain amount of (W)ETH?

Use the [PriceOracle](contracts/utils/PriceOracle.sol). Note that if the user is paying fees with ETH (and not LINK), then that should be deducted. If LINK is used for payment, then the fee in LINK is separately approved so the entire amount of ETH can be used for deposit

#### If at the moment of transaction execution, the balance of the LST pool on L2 changes and is insufficient for the transaction, do we receive a specific error informing us of this?

It will revert with a `OraclePoolInsufficientTokenOut` if the balance of the oraclePool is insufficient to send the tokens to the user

#### How do we track the request status for Fast Stake?

From a user / operator’s perspective, Fast Stake is instant, so either the user gets the token in the wallet or it would revert

#### How do we track the request status for Slow Stake? <need to udpate>

For SlowStake:

- If the L1 -> L2 transfer is via native bridges: since the native bridges don't necessarily provide a message ID, it's not possible to completely track those. You can still track the L2 -> L1 leg of the journey. Typically we've seen BASE and OP L1 -> L2 bridges finish in roughly 3 mins and ARB bridge seems to be taking ~ 8-9 mins.
- If the L1 -> L2 transfer is via CCIP, then its still possible to track the status based on the original message ID since the L1 -> L2 CCIP message is called within the receiver logic of the L2 -> L1 message

#### For Fast Stake, what do we pass to minAmountOut when calling this from the front end?

This is the minimum amount of the LST (wstETH) that you want from the oracle pool for the amount of ETH. This could be done as a dex where you input a « slippage » and that’s it, but if you want to be more precise, it could be set to amountIn _ (1e18 - oraclePoolFee) / oraclePrice and adding a slight wiggle room of 1 rebalance (in case the oracle gets updated in between, so something like `amountIn _ (1e18 - oraclePoolFee) / (oraclePrice \* (1e18 + 318e16 / 365) / 1e18)` (assuming a 3.18% APR))

#### If the front-end needs to know if fast stake is not possible, is there a way they could monitor it?

Yes, they can query the OraclePool’s balance to check this.

#### Important notes for front ends:

Use the proxy address for the custom sender contract (not implementation) to avoid errors during integration.

If the OraclePool reverts with an `OraclePoolInvalidPrice` error code, then the system should be paused for that protocol. This is to catch the condition of when the exchange rate reported is less than the previously reported exchange rate., which could happen in the case of a slashing condition.

## Usage

This repository uses yarn for package management and foundry for smart contract development.

## Foundry Documentation

https://book.getfoundry.sh/

### Environment Setup

First, copy the `.env.example` file to `.env`.

```shell
$ cp .env.example .env
```

Then, update the `.env` file with the appropriate values.

### Build

```shell
$ yarn build
```

### Test

```shell
$ yarn test
```

### Deploy

```shell
$ forge script --broadcast --verify --multi <path-to-script>
```

If the deployment fails, you can resume the deployment from the last failed transaction by running the following command:

```shell
$ forge script --broadcast --verify --multi --resume <path-to-script>
```
