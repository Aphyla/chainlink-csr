// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract LidoParameters {
    uint64 internal constant ETHEREUM_FORK_BLOCK = 22082991;
    uint64 internal constant ETHEREUM_CCIP_CHAIN_SELECTOR = 5009297550715157269;
    address internal constant ETHEREUM_CCIP_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address internal constant ETHEREUM_LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant ETHEREUM_WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETHEREUM_WSTETH_TOKEN = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant ETHEREUM_TO_ARBITRUM_ROUTER = 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef;
    address internal constant ETHEREUM_TO_OPTIMISM_WSTETH_TOKEN_BRIDGE = 0x76943C0D61395d8F2edF9060e1533529cAe05dE6;
    address internal constant ETHEREUM_TO_BASE_WSTETH_TOKEN_BRIDGE = 0x9de443AdC5A411E83F1878Ef24C3F52C61571e72;
    address internal constant ETHEREUM_TO_LINEA_WSTETH_TOKEN_BRIDGE = 0x051F1D88f0aF5763fB888eC4378b4D8B29ea3319;
    address internal constant ETHEREUM_OWNER = address(0); // If left as address(0), the owner will be the deployer
    /* Origin to Destination Fee Parameters */
    uint128 internal constant ETHEREUM_DESTINATION_MAX_FEE = 0.1e18; // Max fee used by the automation contract when calling sync
    bool internal constant ETHEREUM_DESTINATION_PAY_IN_LINK = false; // Whether the automation contract should pay the fee in LINK or ETH
    uint32 internal constant ETHEREUM_DESTINATION_GAS_LIMIT = 400_000; // Gas limit used by the automation contract when calling sync
    /* Deployment */
    address internal constant ETHEREUM_RECEIVER_PROXY = 0x6F357d53d6bE3238180316BA5F8f11467e164588;
    address internal constant ETHEREUM_RECEIVER_PROXY_ADMIN = 0x88a45d2760b63c1500E3D2E3552b28e5Cdaa37BD;
    address internal constant ETHEREUM_RECEIVER_IMPLEMENTATION = 0x301cBCDA894c932E9EDa3Cf8878f78304e69E367;
    address internal constant ETHEREUM_ARBITRUM_ADAPTER = 0xBf96561e4519182CFA4cebBf95494D9CA5a316f9;
    address internal constant ETHEREUM_OPTIMISM_ADAPTER = 0x328de900860816d29D1367F6903a24D8ed40C997;
    address internal constant ETHEREUM_BASE_ADAPTER = 0x9c27c304cFdf0D9177002ff186A4aE0A5489Aace;

    uint64 internal constant ARBITRUM_FORK_BLOCK = 317422042;
    uint64 internal constant ARBITRUM_CCIP_CHAIN_SELECTOR = 4949039107694359620;
    address internal constant ARBITRUM_CCIP_ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address internal constant ARBITRUM_LINK_TOKEN = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant ARBITRUM_WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant ARBITRUM_WSTETH_TOKEN = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address internal constant ARBITRUM_WSTETH_STETH_DATAFEED = 0xB1552C5e96B312d0Bf8b554186F846C40614a540;
    address internal constant ARBITRUM_OWNER = address(0); // If left as address(0), the owner will be the deployer
    /* Data feed parameters */
    bool internal constant ARBITRUM_WSTETH_STETH_DATAFEED_IS_INVERSE = false; // If the data feed is inverted, i.e. the price returned is the inverse of the price wanted
    uint32 internal constant ARBITRUM_WSTETH_STETH_DATAFEED_HEARTBEAT = 24 hours; // The maximum time between data feed updates
    uint96 internal constant ARBITRUM_ORACLE_POOL_FEE = 0; // The fee to be applied to each swap (in 1e18 scale). It should be set following the rebase APR to prevent any exploit of a slow data feed update and it should also be used to cover the actual gas cost of the sync automation contract
    /* Destination to Origin Fee Parameters */
    uint128 internal constant ARBITRUM_ORIGIN_MAX_SUBMISSION_COST = 0.001e18; // The maximum amount of ETH to be paid for submitting the ticket to the arbitrum bridge
    uint32 internal constant ARBITRUM_ORIGIN_MAX_GAS = 100_000; // The maximum amount of gas used to cover the L2 execution cost
    uint64 internal constant ARBITRUM_ORIGIN_GAS_PRICE_BID = 0.05e9; // The gas price bid for the L2 execution cost
    /* Sync Automation Parameters */
    uint128 internal constant ARBITRUM_MIN_SYNC_AMOUNT = 5e18; // The minimum amount of ETH required to start the sync process by the automation contract
    uint128 internal constant ARBITRUM_MAX_SYNC_AMOUNT = 100e18; // The maximum amount of ETH that can be bridged in a single transaction by the automation contract, this value needs to be set carefully following the max ETH amount that can be bridged using CCIP and the max ETH fee (as it's also bridged)
    uint48 internal constant ARBITRUM_MIN_SYNC_DELAY = 12 hours; // The minimum time between syncs by the automation contract, this value should be picked following the time required by the CCIP ETH bucket to refill and the LST/LRT update time
    /* Deployment */
    address internal constant ARBITRUM_SENDER_PROXY = 0x72229141D4B016682d3618ECe47c046f30Da4AD1;
    address internal constant ARBITRUM_SENDER_PROXY_ADMIN = 0x5B42aEbFe95247f1d22e282831e2A513bF050217;
    address internal constant ARBITRUM_SENDER_IMPLEMENTATION = 0x220F64A4793Bc8aca7330ceCc4ae4e2F3B5Bc664;
    address internal constant ARBITRUM_PRICE_ORACLE = 0x328de900860816d29D1367F6903a24D8ed40C997;
    address internal constant ARBITRUM_ORACLE_POOL = 0x9c27c304cFdf0D9177002ff186A4aE0A5489Aace;
    address internal constant ARBITRUM_SYNC_AUTOMATION = 0x7EbD06BF137077fF5EE858ca6368dBd95DB7c66A;

    uint64 internal constant OPTIMISM_FORK_BLOCK = 133406993;
    uint64 internal constant OPTIMISM_CCIP_CHAIN_SELECTOR = 3734403246176062136;
    address internal constant OPTIMISM_CCIP_ROUTER = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;
    address internal constant OPTIMISM_LINK_TOKEN = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
    address internal constant OPTIMISM_WETH_TOKEN = 0x4200000000000000000000000000000000000006;
    address internal constant OPTIMISM_WSTETH_TOKEN = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
    address internal constant OPTIMISM_WSTETH_STETH_DATAFEED = 0xe59EBa0D492cA53C6f46015EEa00517F2707dc77;
    address internal constant OPTIMISM_OWNER = address(0); // If left as address(0), the owner will be the deployer
    /* Data feed parameters */
    bool internal constant OPTIMISM_WSTETH_STETH_DATAFEED_IS_INVERSE = false; // If the data feed is inverted, i.e. the price returned is the inverse of the price wanted
    uint32 internal constant OPTIMISM_WSTETH_STETH_DATAFEED_HEARTBEAT = 24 hours; // The maximum time between data feed updates
    uint96 internal constant OPTIMISM_ORACLE_POOL_FEE = 0; // The fee to be applied to each swap (in 1e18 scale). It should be set following the rebase APR to prevent any exploit of a slow data feed update and it should also be used to cover the actual gas cost of the sync automation contract
    /* Destination to Origin Fee Parameters */
    uint32 internal constant OPTIMISM_ORIGIN_L2_GAS = 100_000; // The amount of gas used to cover the L2 execution cost
    /* Sync Automation Parameters */
    uint128 internal constant OPTIMISM_MIN_SYNC_AMOUNT = 5e18; // The minimum amount of ETH required to start the sync process by the automation contract
    uint128 internal constant OPTIMISM_MAX_SYNC_AMOUNT = 100e18; // The maximum amount of ETH that can be bridged in a single transaction by the automation contract, this value needs to be set carefully following the max ETH amount that can be bridged using CCIP and the max ETH fee (as it's also bridged)
    uint48 internal constant OPTIMISM_MIN_SYNC_DELAY = 12 hours; // The minimum time between syncs by the automation contract, this value should be picked following the time required by the CCIP ETH bucket to refill and the LST/LRT update time
    /* Deployment */
    address internal constant OPTIMISM_SENDER_PROXY = 0x328de900860816d29D1367F6903a24D8ed40C997;
    address internal constant OPTIMISM_SENDER_PROXY_ADMIN = 0x4c8c4A15c1e810e481c412A9B06Be5f79dC02192;
    address internal constant OPTIMISM_SENDER_IMPLEMENTATION = 0x65498495DdC07c52E12EEe3c44D3a1166eed8703;
    address internal constant OPTIMISM_PRICE_ORACLE = 0x301cBCDA894c932E9EDa3Cf8878f78304e69E367;
    address internal constant OPTIMISM_ORACLE_POOL = 0x6F357d53d6bE3238180316BA5F8f11467e164588;
    address internal constant OPTIMISM_SYNC_AUTOMATION = 0x3776CC14ce997827F7A87091018Daa1739dc2790;

    uint64 internal constant BASE_FORK_BLOCK = 27811711;
    uint64 internal constant BASE_CCIP_CHAIN_SELECTOR = 15971525489660198786;
    address internal constant BASE_CCIP_ROUTER = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    address internal constant BASE_LINK_TOKEN = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address internal constant BASE_WETH_TOKEN = 0x4200000000000000000000000000000000000006;
    address internal constant BASE_WSTETH_TOKEN = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant BASE_WSTETH_STETH_DATAFEED = 0xB88BAc61a4Ca37C43a3725912B1f472c9A5bc061;
    address internal constant BASE_OWNER = address(0); // If left as address(0), the owner will be the deployer
    /* Data feed parameters */
    bool internal constant BASE_WSTETH_STETH_DATAFEED_IS_INVERSE = false; // If the data feed is inverted, i.e. the price returned is the inverse of the price wanted
    uint32 internal constant BASE_WSTETH_STETH_DATAFEED_HEARTBEAT = 24 hours; // The maximum time between data feed updates
    uint96 internal constant BASE_ORACLE_POOL_FEE = 0; // The fee to be applied to each swap (in 1e18 scale). It should be set following the rebase APR to prevent any exploit of a slow data feed update and it should also be used to cover the actual gas cost of the sync automation contract
    /* Destination to Origin Fee Parameters */
    uint32 internal constant BASE_ORIGIN_L2_GAS = 100_000; // The amount of gas used to cover the L2 execution cost
    /* Sync Automation Parameters */
    uint128 internal constant BASE_MIN_SYNC_AMOUNT = 5e18; // The minimum amount of ETH required to start the sync process by the automation contract
    uint128 internal constant BASE_MAX_SYNC_AMOUNT = 100e18; // The maximum amount of ETH that can be bridged in a single transaction by the automation contract, this value needs to be set carefully following the max ETH amount that can be bridged using CCIP and the max ETH fee (as it's also bridged)
    uint48 internal constant BASE_MIN_SYNC_DELAY = 12 hours; // The minimum time between syncs by the automation contract, this value should be picked following the time required by the CCIP ETH bucket to refill and the LST/LRT update time
    /* Deployment */
    address internal constant BASE_SENDER_PROXY = 0x328de900860816d29D1367F6903a24D8ed40C997;
    address internal constant BASE_SENDER_PROXY_ADMIN = 0x4c8c4A15c1e810e481c412A9B06Be5f79dC02192;
    address internal constant BASE_SENDER_IMPLEMENTATION = 0x65498495DdC07c52E12EEe3c44D3a1166eed8703;
    address internal constant BASE_PRICE_ORACLE = 0x301cBCDA894c932E9EDa3Cf8878f78304e69E367;
    address internal constant BASE_ORACLE_POOL = 0x6F357d53d6bE3238180316BA5F8f11467e164588;
    address internal constant BASE_SYNC_AUTOMATION = 0x3776CC14ce997827F7A87091018Daa1739dc2790;
}
