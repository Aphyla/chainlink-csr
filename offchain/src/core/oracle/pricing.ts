import { formatUnits } from 'ethers';
import type { JsonRpcProvider } from 'ethers';
import type { Address } from '@/types';
import { PriceOracle__factory } from '@/generated/typechain';
import type { OracleData, FormattedOracleData } from './interfaces';

/**
 * Fetch oracle pricing data from a PriceOracle contract.
 *
 * @param oracleAddress - Price oracle contract address
 * @param provider - JSON-RPC provider
 * @returns Oracle pricing data including price, heartbeat, and configuration
 */
export async function fetchOracleData(
  oracleAddress: Address,
  provider: JsonRpcProvider
): Promise<OracleData> {
  const oracle = PriceOracle__factory.connect(oracleAddress, provider);

  const [price, isInverse, heartbeat, decimals] = await Promise.all([
    oracle.getLatestAnswer(),
    oracle.IS_INVERSE(),
    oracle.HEARTBEAT(),
    oracle.DECIMALS(),
  ]);

  return {
    price,
    isInverse,
    heartbeat,
    decimals: Number(decimals),
    address: oracleAddress,
  };
}

/**
 * Fetch formatted oracle data for display purposes.
 * Includes human-readable price and heartbeat formatting.
 *
 * @param oracleAddress - Price oracle contract address
 * @param provider - JSON-RPC provider
 * @returns Formatted oracle data ready for display
 */
export async function fetchFormattedOracleData(
  oracleAddress: Address,
  provider: JsonRpcProvider
): Promise<FormattedOracleData> {
  const oracleData = await fetchOracleData(oracleAddress, provider);

  return {
    ...oracleData,
    formattedPrice: formatUnits(oracleData.price, oracleData.decimals),
    formattedHeartbeat: formatHeartbeat(oracleData.heartbeat),
  };
}

/**
 * Format heartbeat duration into human-readable format.
 *
 * @param seconds - Heartbeat duration in seconds
 * @returns Human-readable duration string
 */
export function formatHeartbeat(seconds: bigint): string {
  const totalSeconds = Number(seconds);

  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const remainingSeconds = totalSeconds % 60;

  const parts: string[] = [];

  if (days > 0) parts.push(`${days} day${days !== 1 ? 's' : ''}`);
  if (hours > 0) parts.push(`${hours} hour${hours !== 1 ? 's' : ''}`);
  if (minutes > 0) parts.push(`${minutes} minute${minutes !== 1 ? 's' : ''}`);
  if (remainingSeconds > 0 || parts.length === 0) {
    parts.push(
      `${remainingSeconds} second${remainingSeconds !== 1 ? 's' : ''}`
    );
  }

  return parts.join(', ');
}

/**
 * Calculate fee percentage from fee rate.
 *
 * @param feeRate - Fee rate (1e18 scale)
 * @param precision - Decimal places for percentage (default: 2)
 * @returns Fee percentage as string (e.g., "1.50%")
 */
export function formatFeePercentage(
  feeRate: bigint,
  precision: number = 2
): string {
  // Convert from 1e18 scale to percentage
  // feeRate / 1e18 * 100 = feeRate / 1e16
  const percentage = Number(feeRate / 10n ** 16n) / 100;
  return `${percentage.toFixed(precision)}%`;
}
