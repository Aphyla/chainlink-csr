// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LidoParameters {
    string internal constant ETHEREUM_RPC_URL = "https://rpc.ankr.com/eth";
    uint64 internal constant ETHEREUM_FORK_BLOCK = 20034413;
    uint64 internal constant ETHEREUM_CCIP_CHAIN_SELECTOR = 5009297550715157269;
    address internal constant ETHEREUM_CCIP_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address internal constant ETHEREUM_LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant ETHEREUM_WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETHEREUM_WSTETH_TOKEN = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant ETHEREUM_TO_ARBITRUM_ROUTER = 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef;
    address internal constant ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE = 0x76943C0D61395d8F2edF9060e1533529cAe05dE6;

    string internal constant ARBITRUM_RPC_URL = "https://rpc.ankr.com/arbitrum";
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

    string internal constant OPTIMISM_RPC_URL = "https://rpc.ankr.com/optimism";
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
}