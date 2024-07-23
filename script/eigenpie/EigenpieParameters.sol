// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EigenpieParameters {
    uint64 internal constant ETHEREUM_FORK_BLOCK = 20200302;
    uint64 internal constant ETHEREUM_CCIP_CHAIN_SELECTOR = 5009297550715157269;
    address internal constant ETHEREUM_CCIP_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address internal constant ETHEREUM_LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant ETHEREUM_WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETHEREUM_EGETH_TOKEN = 0x18f313Fc6Afc9b5FD6f0908c1b3D476E3feA1DD9;
    address internal constant ETHEREUM_EGETH_STAKING = 0x24db6717dB1C75B9Db6eA47164D8730B63875dB7;

    uint64 internal constant ARBITRUM_FORK_BLOCK = 227088984;
    uint64 internal constant ARBITRUM_CCIP_CHAIN_SELECTOR = 4949039107694359620;
    address internal constant ARBITRUM_CCIP_ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address internal constant ARBITRUM_LINK_TOKEN = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant ARBITRUM_WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant ARBITRUM_EGETH_TOKEN = 0x0000000000000000000000000000000000000000;
    address internal constant ARBITRUM_EGETH_ETHEREUM_DATAFEED = 0x0000000000000000000000000000000000000000;
    address internal constant ARBITRUM_EGETH_ETH_DATAFEED = 0x0000000000000000000000000000000000000000;
    bool internal constant ARBITRUM_EGETH_ETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant ARBITRUM_EGETH_ETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant ARBITRUM_ORACLE_POOL_FEE = 0.01e18;

    uint64 internal constant OPTIMISM_FORK_BLOCK = 122050541;
    uint64 internal constant OPTIMISM_CCIP_CHAIN_SELECTOR = 3734403246176062136;
    address internal constant OPTIMISM_CCIP_ROUTER = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;
    address internal constant OPTIMISM_LINK_TOKEN = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
    address internal constant OPTIMISM_WETH_TOKEN = 0x4200000000000000000000000000000000000006;
    address internal constant OPTIMISM_EGETH_TOKEN = 0x0000000000000000000000000000000000000000;
    address internal constant OPTIMISM_EGETH_ETHEREUM_DATAFEED = 0x0000000000000000000000000000000000000000;
    address internal constant OPTIMISM_EGETH_ETH_DATAFEED = 0x0000000000000000000000000000000000000000;
    bool internal constant OPTIMISM_EGETH_ETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant OPTIMISM_EGETH_ETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant OPTIMISM_ORACLE_POOL_FEE = 0.01e18;
}