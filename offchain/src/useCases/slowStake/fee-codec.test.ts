/**
 * @fileoverview Fee Codec Test Suite
 *
 * Comprehensive test suite for the fee codec implementation that mirrors Solidity FeeCodec.sol
 * Verifies compatibility, validation, and edge cases across all supported bridges.
 */

import { describe, it, expect } from 'vitest';
import {
  encodeCCIPFee,
  encodeArbitrumL1toL2Fee,
  encodeOptimismL1toL2Fee,
  encodeBaseL1toL2Fee,
  validateCCIPParams,
  validateArbitrumParams,
  validateOptimismParams,
  isValidCCIPParams,
  isValidArbitrumParams,
  isValidOptimismParams,
  calculateArbitrumFeeAmount,
  getExpectedByteLength,
  type CCIPFeeParams,
  type ArbitrumL1toL2FeeParams,
  type OptimismL1toL2FeeParams,
} from './fee-codec';

describe('Fee Codec', () => {
  describe('CCIP Fee Encoding', () => {
    it('should encode CCIP fees with correct structure and format', () => {
      const params: CCIPFeeParams = {
        maxFee: 1000000000000000000n, // 1 ETH
        payInLink: false,
        gasLimit: 1000000,
      };

      const encoded = encodeCCIPFee(params);

      // Should be 21 bytes = 42 hex chars + 0x prefix
      expect(encoded).toHaveLength(44);
      expect(encoded).toMatch(/^0x[0-9a-f]+$/i);

      // Verify byte structure
      const hex = encoded.slice(2);
      const payInLinkHex = hex.slice(32, 34); // 1 byte
      const gasLimitHex = hex.slice(34, 42); // 4 bytes

      expect(payInLinkHex).toBe('00'); // payInLink = false
      expect(gasLimitHex).toBe('000f4240'); // gasLimit = 1000000
    });

    it('should handle payInLink = true correctly', () => {
      const params: CCIPFeeParams = {
        maxFee: 500000000000000000n,
        payInLink: true,
        gasLimit: 500000,
      };

      const encoded = encodeCCIPFee(params);
      const hex = encoded.slice(2);
      const payInLinkHex = hex.slice(32, 34);

      expect(payInLinkHex).toBe('01'); // payInLink = true
    });
  });

  describe('Arbitrum L1→L2 Fee Encoding', () => {
    it('should encode Arbitrum fees with correct fee calculation', () => {
      const params: ArbitrumL1toL2FeeParams = {
        maxSubmissionCost: 10000000000000000n, // 0.01 ETH
        maxGas: 100000,
        gasPriceBid: 45000000000n, // 45 gwei
      };

      const encoded = encodeArbitrumL1toL2Fee(params);

      // Should be 29 bytes = 58 hex chars + 0x prefix
      expect(encoded).toHaveLength(60);
      expect(encoded).toMatch(/^0x[0-9a-f]+$/i);

      // Calculate expected feeAmount
      const expectedFeeAmount =
        params.maxSubmissionCost + params.gasPriceBid * BigInt(params.maxGas);
      expect(expectedFeeAmount).toBe(14500000000000000n);
    });

    it('should handle zero values correctly', () => {
      const params: ArbitrumL1toL2FeeParams = {
        maxSubmissionCost: 0n,
        maxGas: 0,
        gasPriceBid: 0n,
      };

      const encoded = encodeArbitrumL1toL2Fee(params);
      expect(encoded).toHaveLength(60);
    });
  });

  describe('Optimism L1→L2 Fee Encoding', () => {
    it('should encode Optimism fees with zero fee amount', () => {
      const params: OptimismL1toL2FeeParams = {
        l2Gas: 100000,
      };

      const encoded = encodeOptimismL1toL2Fee(params);

      // Should be 21 bytes = 42 hex chars + 0x prefix
      expect(encoded).toHaveLength(44);

      // Should start with zeros (feeAmount = 0, payInLink = false)
      const hex = encoded.slice(2);
      expect(hex.slice(0, 34)).toBe('0000000000000000000000000000000000');
      expect(hex.slice(34, 42)).toBe('000186a0'); // l2Gas = 100000
    });

    it('should match live Base example from production', () => {
      const params: OptimismL1toL2FeeParams = {
        l2Gas: 100000,
      };

      const encoded = encodeOptimismL1toL2Fee(params);

      // This should match the live Base example provided by the user
      expect(encoded).toBe('0x0000000000000000000000000000000000000186a0');
    });
  });

  describe('Base L1→L2 Fee Encoding', () => {
    it('should be identical to Optimism encoding', () => {
      const params: OptimismL1toL2FeeParams = {
        l2Gas: 100000,
      };

      const optimismEncoded = encodeOptimismL1toL2Fee(params);
      const baseEncoded = encodeBaseL1toL2Fee(params);

      expect(baseEncoded).toBe(optimismEncoded);
    });

    it('should match live Base network data', () => {
      const params: OptimismL1toL2FeeParams = {
        l2Gas: 100000,
      };

      const encoded = encodeBaseL1toL2Fee(params);
      expect(encoded).toBe('0x0000000000000000000000000000000000000186a0');
    });
  });

  describe('Validation Functions', () => {
    describe('CCIP Validation', () => {
      it('should accept valid CCIP parameters', () => {
        const validParams: CCIPFeeParams = {
          maxFee: 1000000000000000000n,
          payInLink: false,
          gasLimit: 1000000,
        };

        expect(() => validateCCIPParams(validParams)).not.toThrow();
      });

      it('should reject maxFee exceeding uint128', () => {
        const invalidParams: CCIPFeeParams = {
          maxFee: 2n ** 128n, // Exceeds uint128
          payInLink: false,
          gasLimit: 1000000,
        };

        expect(() => validateCCIPParams(invalidParams)).toThrow('maxFee');
      });

      it('should reject gasLimit exceeding uint32', () => {
        const invalidParams: CCIPFeeParams = {
          maxFee: 1000000000000000000n,
          payInLink: false,
          gasLimit: 0x100000000, // Exceeds uint32
        };

        expect(() => validateCCIPParams(invalidParams)).toThrow('gasLimit');
      });
    });

    describe('Arbitrum Validation', () => {
      it('should accept valid Arbitrum parameters', () => {
        const validParams: ArbitrumL1toL2FeeParams = {
          maxSubmissionCost: 10000000000000000n,
          maxGas: 100000,
          gasPriceBid: 45000000000n,
        };

        expect(() => validateArbitrumParams(validParams)).not.toThrow();
      });

      it('should reject negative values', () => {
        const invalidParams: ArbitrumL1toL2FeeParams = {
          maxSubmissionCost: -1n,
          maxGas: 100000,
          gasPriceBid: 45000000000n,
        };

        expect(() => validateArbitrumParams(invalidParams)).toThrow(
          'maxSubmissionCost'
        );
      });
    });

    describe('Optimism Validation', () => {
      it('should accept valid Optimism parameters', () => {
        const validParams: OptimismL1toL2FeeParams = {
          l2Gas: 100000,
        };

        expect(() => validateOptimismParams(validParams)).not.toThrow();
      });

      it('should reject negative l2Gas', () => {
        const invalidParams: OptimismL1toL2FeeParams = {
          l2Gas: -1,
        };

        expect(() => validateOptimismParams(invalidParams)).toThrow('l2Gas');
      });
    });
  });

  describe('Type Guards', () => {
    it('should correctly identify valid CCIP parameters', () => {
      const validParams = {
        maxFee: 1000000000000000000n,
        payInLink: false,
        gasLimit: 1000000,
      };

      expect(isValidCCIPParams(validParams)).toBe(true);
    });

    it('should reject invalid CCIP parameter types', () => {
      const invalidParams = {
        maxFee: '1000000000000000000', // string instead of bigint
        payInLink: false,
        gasLimit: 1000000,
      };

      expect(isValidCCIPParams(invalidParams)).toBe(false);
    });

    it('should correctly identify valid Arbitrum parameters', () => {
      const validParams = {
        maxSubmissionCost: 10000000000000000n,
        maxGas: 100000,
        gasPriceBid: 45000000000n,
      };

      expect(isValidArbitrumParams(validParams)).toBe(true);
    });

    it('should correctly identify valid Optimism parameters', () => {
      const validParams = {
        l2Gas: 100000,
      };

      expect(isValidOptimismParams(validParams)).toBe(true);
    });

    it('should handle null and undefined inputs', () => {
      expect(isValidCCIPParams(null)).toBe(false);
      expect(isValidCCIPParams(undefined)).toBe(false);
      expect(isValidArbitrumParams(null)).toBe(false);
      expect(isValidOptimismParams(undefined)).toBe(false);
    });
  });

  describe('Utility Functions', () => {
    describe('calculateArbitrumFeeAmount', () => {
      it('should calculate fee amount correctly', () => {
        const params: ArbitrumL1toL2FeeParams = {
          maxSubmissionCost: 10000000000000000n,
          maxGas: 100000,
          gasPriceBid: 45000000000n,
        };

        const feeAmount = calculateArbitrumFeeAmount(params);
        const expected = 10000000000000000n + 45000000000n * 100000n;

        expect(feeAmount).toBe(expected);
      });

      it('should throw on fee amount overflow', () => {
        const params: ArbitrumL1toL2FeeParams = {
          maxSubmissionCost: 2n ** 128n - 1n, // max uint128
          maxGas: 1000000,
          gasPriceBid: 1000000000n, // This will cause overflow when multiplied
        };

        expect(() => calculateArbitrumFeeAmount(params)).toThrow(
          'exceeds uint128'
        );
      });
    });

    describe('getExpectedByteLength', () => {
      it('should return correct byte lengths for each bridge type', () => {
        expect(getExpectedByteLength('ccip')).toBe(21);
        expect(getExpectedByteLength('arbitrum')).toBe(29);
        expect(getExpectedByteLength('optimism')).toBe(21);
        expect(getExpectedByteLength('base')).toBe(21);
      });

      it('should throw for unknown bridge types', () => {
        expect(() => getExpectedByteLength('unknown' as never)).toThrow(
          'Unknown bridge type'
        );
      });
    });
  });

  describe('Integration Test Values', () => {
    it('should match Solidity test values for Arbitrum', () => {
      // Values from CCIPIntegrationLIDO.t.sol
      const params: ArbitrumL1toL2FeeParams = {
        maxSubmissionCost: 10000000000000000n, // 0.01e18
        maxGas: 100000,
        gasPriceBid: 45000000000n, // 45e9
      };

      const encoded = encodeArbitrumL1toL2Fee(params);
      expect(encoded).toHaveLength(60);
      expect(encoded).toMatch(/^0x[0-9a-f]+$/i);
    });

    it('should match Solidity test values for Optimism', () => {
      const params: OptimismL1toL2FeeParams = {
        l2Gas: 100000,
      };

      const encoded = encodeOptimismL1toL2Fee(params);
      expect(encoded).toHaveLength(44);
      expect(encoded).toBe('0x0000000000000000000000000000000000000186a0');
    });
  });

  describe('Edge Cases', () => {
    it('should handle zero values for all bridge types', () => {
      const zeroCCIPParams: CCIPFeeParams = {
        maxFee: 0n,
        payInLink: false,
        gasLimit: 0,
      };

      const zeroArbitrumParams: ArbitrumL1toL2FeeParams = {
        maxSubmissionCost: 0n,
        maxGas: 0,
        gasPriceBid: 0n,
      };

      const zeroOptimismParams: OptimismL1toL2FeeParams = {
        l2Gas: 0,
      };

      expect(() => encodeCCIPFee(zeroCCIPParams)).not.toThrow();
      expect(() => encodeArbitrumL1toL2Fee(zeroArbitrumParams)).not.toThrow();
      expect(() => encodeOptimismL1toL2Fee(zeroOptimismParams)).not.toThrow();
    });

    it('should handle maximum valid values', () => {
      const maxCCIPParams: CCIPFeeParams = {
        maxFee: 2n ** 128n - 1n, // max uint128
        payInLink: true,
        gasLimit: 0xffffffff, // max uint32
      };

      expect(() => encodeCCIPFee(maxCCIPParams)).not.toThrow();
    });
  });

  describe('Output Format Verification', () => {
    it('should produce valid hex strings with correct prefixes', () => {
      const ccipParams: CCIPFeeParams = {
        maxFee: 1000000000000000000n,
        payInLink: false,
        gasLimit: 1000000,
      };

      const encoded = encodeCCIPFee(ccipParams);

      // Should be valid hex
      expect(encoded).toMatch(/^0x[0-9a-f]+$/i);
      expect(encoded).toHaveLength(44);
      expect((encoded.length - 2) / 2).toBe(21); // 21 bytes
    });

    it('should use lowercase hex characters', () => {
      const params: OptimismL1toL2FeeParams = {
        l2Gas: 255, // 0xff
      };

      const encoded = encodeOptimismL1toL2Fee(params);
      expect(encoded).toMatch(/^0x[0-9a-f]+$/); // lowercase only
    });
  });
});
