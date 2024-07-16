# ChainLink Custom Sender-Receiver

The ChainLink Custom Sender-Receiver is a set of smart contracts that allow users to stake a token on a L2 and receive the L1 native token directly on the L2 chain. For example, a user can stake (W)ETH on Arbitrum or Optimism and receive wstETH directly on the same chain.

## Fast Stake

The `fastStake` function from the [CustomSender](contracts/senders/CustomSender.sol) contract can be used to use a [OraclePool](contracts/utils/OraclePool.sol) to swap (W)ETH for a Liquid Staked Token (LST) on the same chain using an exchange rate oracle.
The (W)ETH that accumulates in the pool can be sent to the L1 chain to mint the LST using the `sync` function from the [CustomSender](contracts/senders/CustomSender.sol) contract. The (W)ETH will be sent to the [CustomReceiver](contracts/receivers/CustomReceiver.sol) contract on the L1 chain that will mint the LST and send it back to the pool on the L2 chain.

![alt text](images/fast_stake.png)

## Slow Stake

The `slowStake` function from the [CustomSender](contracts/senders/CustomSender.sol) contract can be used to send (W)ETH to the [CustomReceiver](contracts/receivers/CustomReceiver.sol) contract on the L1 chain. The (W)ETH sent will be used to mint the LST and send it back to the user on the L2 chain.

![alt text](images/slow_stake.png)

## How to adapt the contracts to your own LST/LRT

To adapt the contracts for new use case, the following steps need to be taken:

#### Custom Receiver

Implement the `_depositNative` from [CustomReceiver](contracts/receivers/CustomReceiver.sol#L155) and add the logic to mint the LST/LRT from native tokens. For example, wrap the ETH to weth, and then mint the LST/LRT. Don't forget to return the amount of LST/LRT tokens minted.

Note that if the contract implementing the `_depositNative` function requires some values to be set in storage, it is very important to follow the EIP-7201 to prevent storage collisions. It is therefore very important to make sure that the hash used for the storage location is unique. It is highly recommended to use the following hash function to generate the storage location: `keccak256(abi.encode(uint256(keccak256("ccip-csr.storage.<NAME_OF_THE_CONTRACT>")) - 1)) & ~bytes32(uint256(0xff))`.
Do not forget to replace `<NAME_OF_THE_CONTRACT>` with the name of the contract, and that the name used is unique.

#### Bridge Adapter

If the bridge is not supported (currently, only OPTIMISM, ARBITRUM and CCIP bridges are supported), inherit the [BridgeAdapter](contracts/adapaters/BridgeAdapter.sol) contract and implement the `_sendToken` function.

Note that bridge adapters should not store any data in storage, as this would lead to storage collisions.

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
