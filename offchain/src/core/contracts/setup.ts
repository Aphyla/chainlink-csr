import { ZeroAddress } from 'ethers';
import type { SupportedChainId } from '@/types';
import { createProvider } from '@/config/wallet';
import {
  CustomSenderReferral__factory,
  OraclePool__factory,
  PriceOracle__factory,
  IERC20__factory,
} from '@/generated/typechain';
import type { ProtocolConfig } from '@/core/protocols/interfaces';
import type { ContractSetupResult } from './interfaces';

/**
 * Parameters for setting up liquid staking contracts.
 */
export interface SetupLiquidStakingContractsParams {
  /** Supported chain ID for operations */
  readonly chainKey: SupportedChainId;
  /** Protocol configuration to use */
  readonly protocol: ProtocolConfig;
}

/**
 * Protocol-agnostic setup for liquid staking contracts.
 *
 * This function eliminates the code duplication across all use cases by
 * providing a single point for contract setup. It works with any liquid
 * staking protocol that follows the CustomSender + OraclePool pattern.
 *
 * The function:
 * 1. Creates a provider for the specified chain
 * 2. Connects to the CustomSenderReferral contract
 * 3. Retrieves OraclePool and other contract addresses
 * 4. Connects to all necessary contracts
 * 5. Returns everything ready for use
 *
 * @param params - Setup parameters including chain and protocol
 * @returns Complete contract setup with addresses and instances
 * @throws Error if protocol is not supported on the chain or contracts are misconfigured
 */
export async function setupLiquidStakingContracts(
  params: SetupLiquidStakingContractsParams
): Promise<ContractSetupResult> {
  const { chainKey, protocol } = params;

  // 1. Validate protocol support on chain
  const customSenderAddress = protocol.customSenderAddresses[chainKey];
  if (!customSenderAddress) {
    throw new Error(
      `Protocol "${protocol.name}" is not supported on chain ${chainKey}. ` +
        `Supported chains: ${Object.keys(protocol.customSenderAddresses).join(', ')}`
    );
  }

  // 2. Create provider for the specified chain
  const provider = createProvider(chainKey);

  // 3. Connect to CustomSenderReferral contract
  const customSender = CustomSenderReferral__factory.connect(
    customSenderAddress,
    provider
  );

  // 4. Get basic contract configuration from CustomSenderReferral
  const [oraclePoolAddress, wnativeAddress, linkTokenAddress] =
    await Promise.all([
      customSender.getOraclePool(),
      customSender.WNATIVE(),
      customSender.LINK_TOKEN(),
    ]);

  if (oraclePoolAddress === ZeroAddress) {
    throw new Error(
      `OraclePool not set on CustomSenderReferral for protocol "${protocol.name}" ` +
        `on chain ${chainKey}. Contract may not be properly configured.`
    );
  }

  // 5. Connect to OraclePool and get configuration
  const oraclePool = OraclePool__factory.connect(oraclePoolAddress, provider);
  const [oracleAddress, tokenInAddress, tokenOutAddress] = await Promise.all([
    oraclePool.getOracle(),
    oraclePool.TOKEN_IN(),
    oraclePool.TOKEN_OUT(),
  ]);

  // 6. Connect to all contracts
  const priceOracle = PriceOracle__factory.connect(oracleAddress, provider);
  const tokenIn = IERC20__factory.connect(tokenInAddress, provider);
  const tokenOut = IERC20__factory.connect(tokenOutAddress, provider);

  // 7. Build complete result
  return {
    provider,
    protocolName: protocol.name,
    chainKey,
    addresses: {
      customSender: customSenderAddress,
      oraclePool: oraclePoolAddress,
      priceOracle: oracleAddress,
      tokenIn: tokenInAddress,
      tokenOut: tokenOutAddress,
      wnative: wnativeAddress,
      linkToken: linkTokenAddress,
    },
    contracts: {
      customSender,
      oraclePool,
      priceOracle,
      tokenIn,
      tokenOut,
    },
  };
}
