/**
 * Central type definitions for the Chainlink CSR Liquid Staking Framework.
 *
 * This module contains common types used across multiple parts of the application
 * to ensure consistency and avoid duplication.
 */

/**
 * Payment method for staking operations.
 * Determines whether to use native ETH or wrapped native token (WETH).
 */
export type PaymentMethod = 'native' | 'wrapped';

/**
 * Fee payment method for CCIP operations.
 * Determines whether CCIP fees are paid in native ETH or LINK token.
 */
export type CCIPFeePaymentMethod = 'native' | 'link';

/**
 * Slippage tolerance levels for operations.
 * Predefined common slippage values for better UX.
 */
export type SlippageTolerance = 0.001 | 0.005 | 0.01 | 0.02 | 0.05; // 0.1%, 0.5%, 1%, 2%, 5%

/**
 * Common parameter validation helpers
 */
export const PaymentMethodValues = ['native', 'wrapped'] as const;
export const CCIPFeePaymentMethodValues = ['native', 'link'] as const;

/**
 * Type guards for runtime validation
 */
export function isValidPaymentMethod(value: unknown): value is PaymentMethod {
  return (
    typeof value === 'string' &&
    PaymentMethodValues.includes(value as PaymentMethod)
  );
}

export function isValidCCIPFeePaymentMethod(
  value: unknown
): value is CCIPFeePaymentMethod {
  return (
    typeof value === 'string' &&
    CCIPFeePaymentMethodValues.includes(value as CCIPFeePaymentMethod)
  );
}
