// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LidoParameters {
    uint64 internal constant ETHEREUM_FORK_BLOCK = 20591103;
    uint64 internal constant ETHEREUM_CCIP_CHAIN_SELECTOR = 5009297550715157269;
    address internal constant ETHEREUM_CCIP_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address internal constant ETHEREUM_LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant ETHEREUM_WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETHEREUM_WSTETH_TOKEN = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant ETHEREUM_TO_ARBITRUM_ROUTER = 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef;
    address internal constant ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE = 0x76943C0D61395d8F2edF9060e1533529cAe05dE6;
    address internal constant ETHEREUM_TO_BASE_STANDARD_BRIDGE = 0x3154Cf16ccdb4C6d922629664174b904d80F2C35;

    uint64 internal constant ARBITRUM_FORK_BLOCK = 219083410;
    uint64 internal constant ARBITRUM_CCIP_CHAIN_SELECTOR = 4949039107694359620;
    address internal constant ARBITRUM_CCIP_ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address internal constant ARBITRUM_LINK_TOKEN = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant ARBITRUM_WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant ARBITRUM_WSTETH_TOKEN = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address internal constant ARBITRUM_WSTETH_STETH_DATAFEED = 0xB1552C5e96B312d0Bf8b554186F846C40614a540;
    bool internal constant ARBITRUM_WSTETH_STETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant ARBITRUM_ORACLE_POOL_FEE = 0.01e18;

    uint64 internal constant OPTIMISM_FORK_BLOCK = 121425199;
    uint64 internal constant OPTIMISM_CCIP_CHAIN_SELECTOR = 3734403246176062136;
    address internal constant OPTIMISM_CCIP_ROUTER = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;
    address internal constant OPTIMISM_LINK_TOKEN = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
    address internal constant OPTIMISM_WETH_TOKEN = 0x4200000000000000000000000000000000000006;
    address internal constant OPTIMISM_WSTETH_TOKEN = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
    address internal constant OPTIMISM_WSTETH_STETH_DATAFEED = 0xe59EBa0D492cA53C6f46015EEa00517F2707dc77;
    bool internal constant OPTIMISM_WSTETH_STETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant OPTIMISM_ORACLE_POOL_FEE = 0.01e18;

    uint64 internal constant BASE_FORK_BLOCK = 18811140;
    uint64 internal constant BASE_CCIP_CHAIN_SELECTOR = 15971525489660198786;
    address internal constant BASE_CCIP_ROUTER = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    address internal constant BASE_LINK_TOKEN = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address internal constant BASE_WETH_TOKEN = 0x4200000000000000000000000000000000000006;
    address internal constant BASE_WSTETH_TOKEN = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant BASE_WSTETH_STETH_DATAFEED = 0xB88BAc61a4Ca37C43a3725912B1f472c9A5bc061;
    bool internal constant BASE_WSTETH_STETH_DATAFEED_IS_INVERSE = false;
    uint32 internal constant BASE_WSTETH_STETH_DATAFEED_HEARTBEAT = 24 hours;
    uint96 internal constant BASE_ORACLE_POOL_FEE = 0.01e18;
}
