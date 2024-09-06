// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract EigenpieParameters {
    uint64 internal constant ETHEREUM_FORK_BLOCK = 20371005;
    uint64 internal constant ETHEREUM_CCIP_CHAIN_SELECTOR = 5009297550715157269;
    address internal constant ETHEREUM_CCIP_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address internal constant ETHEREUM_LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant ETHEREUM_WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETHEREUM_EGETH_TOKEN = 0x18f313Fc6Afc9b5FD6f0908c1b3D476E3feA1DD9;
    address internal constant ETHEREUM_EGETH_STAKING = 0x24db6717dB1C75B9Db6eA47164D8730B63875dB7;

    uint64 internal constant ARBITRUM_FORK_BLOCK = 235298460;
    uint64 internal constant ARBITRUM_CCIP_CHAIN_SELECTOR = 4949039107694359620;
    address internal constant ARBITRUM_CCIP_ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address internal constant ARBITRUM_LINK_TOKEN = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant ARBITRUM_WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant ARBITRUM_EGETH_TOKEN = 0x6C49A527bdd2E09D4337C8699aA7B44dD053Eda8;
    address internal constant ARBITRUM_EGETH_ETH_DATAFEED = 0xD3631AC9D81eD560D61957a55E9c992cdE497eb6;
    bool internal constant ARBITRUM_EGETH_ETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant ARBITRUM_EGETH_ETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant ARBITRUM_ORACLE_POOL_FEE = 0.01e18;
}
