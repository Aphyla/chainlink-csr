import type { Address, SupportedChainId } from '@/types';

export const LIDO_CUSTOM_SENDER: Record<SupportedChainId, Address> = {
  // Optimism mainnet
  OPTIMISM_MAINNET: '0x328de900860816d29D1367F6903a24D8ed40C997',
  // Arbitrum One
  ARBITRUM_ONE: '0x72229141D4B016682d3618ECe47c046f30Da4AD1',
  // Base mainnet
  BASE_MAINNET: '0x328de900860816d29D1367F6903a24D8ed40C997',
} as const;
