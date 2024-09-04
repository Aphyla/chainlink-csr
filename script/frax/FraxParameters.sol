// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FraxParameters {
    uint64 internal constant ETHEREUM_FORK_BLOCK = 20469124;
    uint64 internal constant ETHEREUM_CCIP_CHAIN_SELECTOR = 5009297550715157269;
    address internal constant ETHEREUM_CCIP_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address internal constant ETHEREUM_LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant ETHEREUM_WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETHEREUM_SFRXETH_TOKEN = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address internal constant ETHEREUM_FRXETH_MINTER = 0xbAFA44EFE7901E04E39Dad13167D089C559c1138;
    address internal constant ETHEREUM_TO_ARBITRUM_FRAX_FERRY = 0x8afd5082E0C24dEcEA39A9eFb14e4ACF4373D7D6;
    address internal constant ETHEREUM_TO_OPTIMISM_FRAX_FERRY = 0x04ba20D2Cc47C63bce1166C2864F0241e4D0a0CC;

    uint64 internal constant ARBITRUM_FORK_BLOCK = 240011124;
    uint64 internal constant ARBITRUM_CCIP_CHAIN_SELECTOR = 4949039107694359620;
    address internal constant ARBITRUM_CCIP_ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address internal constant ARBITRUM_LINK_TOKEN = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant ARBITRUM_WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant ARBITRUM_SFRXETH_TOKEN = 0x95aB45875cFFdba1E5f451B950bC2E42c0053f39;
    address internal constant ARBITRUM_SFRXETH_FRXETH_DATAFEED = 0x98E5a52fB741347199C08a7a3fcF017364284431;
    bool internal constant ARBITRUM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant ARBITRUM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant ARBITRUM_ORACLE_POOL_FEE = 0.01e18;

    uint64 internal constant OPTIMISM_FORK_BLOCK = 123671836;
    uint64 internal constant OPTIMISM_CCIP_CHAIN_SELECTOR = 3734403246176062136;
    address internal constant OPTIMISM_CCIP_ROUTER = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;
    address internal constant OPTIMISM_LINK_TOKEN = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
    address internal constant OPTIMISM_WETH_TOKEN = 0x4200000000000000000000000000000000000006;
    address internal constant OPTIMISM_SFRXETH_TOKEN = 0x484c2D6e3cDd945a8B2DF735e079178C1036578c;
    address internal constant OPTIMISM_SFRXETH_FRXETH_DATAFEED = 0xd2AdD08d9Cd83720c9296A991ce066BB08265eAc;
    bool internal constant OPTIMISM_SFRXETH_FRXETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant OPTIMISM_SFRXETH_FRXETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant OPTIMISM_ORACLE_POOL_FEE = 0.01e18;
}