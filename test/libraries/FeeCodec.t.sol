// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/libraries/FeeCodec.sol";

contract FeeCodecTest is Test {
    function test_Fuzz_EncodePackedData(address recipient, uint256 amount, bytes memory feeData) public pure {
        bytes memory packedData = FeeCodec.encodePackedData(recipient, amount, feeData);

        (address decodedRecipient, uint256 decodedAmount, bytes memory decodedFeeData) =
            FeeCodec.decodePackedData(packedData);

        assertEq(recipient, decodedRecipient, "test_Fuzz_EncodePackedData::1");
        assertEq(amount, decodedAmount, "test_Fuzz_EncodePackedData::2");
        assertEq(feeData, decodedFeeData, "test_Fuzz_EncodePackedData::3");
    }

    function test_Fuzz_Revert_DecodePackedData(bytes memory feeData) public {
        uint256 length = feeData.length > 127 ? 127 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 128));
        FeeCodec.decodePackedData(feeData);
    }

    function test_Fuzz_DecodeFee(uint256 feeAmount, bytes memory additionalData) public pure {
        bytes memory feeData = abi.encodePacked(feeAmount, additionalData);

        uint256 decodedFeeAmount = FeeCodec.decodeFee(feeData);

        assertEq(feeAmount, decodedFeeAmount, "test_Fuzz_DecodeFee::1");
    }

    function test_Fuzz_Revert_DecodeFee(bytes memory feeData) public {
        uint256 length = feeData.length > 31 ? 31 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 32));
        FeeCodec.decodeFee(feeData);
    }

    function test_Fuzz_EncodeCCIP(uint256 maxFee, bool payInLink, uint256 gasLimit) public pure {
        bytes memory feeData = FeeCodec.encodeCCIP(maxFee, payInLink, gasLimit);

        (uint256 decodedMaxFee, bool decodedPayInLink, uint256 decodedGasLimit) = FeeCodec.decodeCCIP(feeData);

        assertEq(maxFee, decodedMaxFee, "test_Fuzz_EncodeCCIP::1");
        assertEq(payInLink, decodedPayInLink, "test_Fuzz_EncodeCCIP::2");
        assertEq(gasLimit, decodedGasLimit, "test_Fuzz_EncodeCCIP::3");
    }

    function test_Fuzz_Revert_DecodeCCIP(bytes memory feeData) public {
        uint256 length = feeData.length > 95 ? 95 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 96));
        FeeCodec.decodeCCIP(feeData);
    }

    function test_Fuzz_EncodeArbitrumL1toL2(uint256 maxSubmissionCost, uint256 maxGas, uint256 gasPriceBid)
        public
        pure
    {
        maxGas = bound(maxGas, 0, gasPriceBid == 0 ? maxGas : (type(uint256).max - maxSubmissionCost) / gasPriceBid);

        bytes memory feeData = FeeCodec.encodeArbitrumL1toL2(maxSubmissionCost, maxGas, gasPriceBid);

        (uint256 decodedFeeAmount, uint256 decodedMaxSubmissionCost, uint256 decodedMaxGas, uint256 decodedGasPriceBid)
        = FeeCodec.decodeArbitrumL1toL2(feeData);

        assertEq(maxSubmissionCost + gasPriceBid * maxGas, decodedFeeAmount, "test_Fuzz_EncodeArbitrumL1toL2::1");
        assertEq(maxSubmissionCost, decodedMaxSubmissionCost, "test_Fuzz_EncodeArbitrumL1toL2::2");
        assertEq(maxGas, decodedMaxGas, "test_Fuzz_EncodeArbitrumL1toL2::3");
        assertEq(gasPriceBid, decodedGasPriceBid, "test_Fuzz_EncodeArbitrumL1toL2::4");
    }

    function test_Fuzz_Revert_DecodeArbitrumL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 127 ? 127 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 128));
        FeeCodec.decodeArbitrumL1toL2(feeData);
    }

    function test_Fuzz_EncodeOptimismL1toL2(uint32 l2Gas) public pure {
        bytes memory feeData = FeeCodec.encodeOptimismL1toL2(l2Gas);

        (uint256 decodedFeeAmount, uint256 decodedL2Gas) = FeeCodec.decodeOptimismL1toL2(feeData);

        assertEq(0, decodedFeeAmount, "test_Fuzz_EncodeOptimismL1toL2::1");
        assertEq(l2Gas, decodedL2Gas, "test_Fuzz_EncodeOptimismL1toL2::2");
    }

    function test_Fuzz_Revert_DecodeOptimismL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 63 ? 63 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 64));
        FeeCodec.decodeOptimismL1toL2(feeData);
    }

    function test_Fuzz_EncodeBaseL1toL2(uint32 l2Gas) public pure {
        bytes memory feeData = FeeCodec.encodeBaseL1toL2(l2Gas);

        (uint256 decodedFeeAmount, uint256 decodedL2Gas) = FeeCodec.decodeBaseL1toL2(feeData);

        assertEq(0, decodedFeeAmount, "test_Fuzz_EncodeBaseL1toL2::1");
        assertEq(l2Gas, decodedL2Gas, "test_Fuzz_EncodeBaseL1toL2::2");
    }

    function test_Fuzz_Revert_DecodeBaseL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 63 ? 63 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 64));
        FeeCodec.decodeBaseL1toL2(feeData);
    }

    function test_EncodeFraxFerryL1toL2() public pure {
        bytes memory feeData = FeeCodec.encodeFraxFerryL1toL2();

        uint256 decodedFeeAmount = FeeCodec.decodeFraxFerryL1toL2(feeData);

        assertEq(0, decodedFeeAmount, "test_EncodeFraxFerryL1toL2::1");
    }

    function test_Revert_DecodeFraxFerryL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 31 ? 31 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 32));
        FeeCodec.decodeFraxFerryL1toL2(feeData);
    }
}
