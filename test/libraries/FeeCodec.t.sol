// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "./FeeCodecHelper.sol";

contract FeeCodecTest is Test {
    FeeCodecHelper feeCodecHelper;

    function setUp() public {
        feeCodecHelper = new FeeCodecHelper();
    }

    function test_Fuzz_EncodePackedData(address recipient, uint256 amount, bytes memory feeData) public view {
        {
            bytes memory packedData = feeCodecHelper.encodePackedData(recipient, amount, feeData);

            {
                (address decodedRecipient, uint256 decodedAmount, bytes memory decodedFeeData) =
                    feeCodecHelper.decodePackedData(packedData);

                assertEq(recipient, decodedRecipient, "test_Fuzz_EncodePackedData::1");
                assertEq(amount, decodedAmount, "test_Fuzz_EncodePackedData::2");
                assertEq(feeData, decodedFeeData, "test_Fuzz_EncodePackedData::3");
            }

            {
                (address decodedRecipient, uint256 decodedAmount, bytes memory decodedFeeData) =
                    feeCodecHelper.decodePackedDataMemory(packedData);

                assertEq(recipient, decodedRecipient, "test_Fuzz_EncodePackedData::4");
                assertEq(amount, decodedAmount, "test_Fuzz_EncodePackedData::5");
                assertEq(feeData, decodedFeeData, "test_Fuzz_EncodePackedData::6");
            }
        }

        {
            bytes memory packedData = feeCodecHelper.encodePackedDataMemory(recipient, amount, feeData);

            {
                (address decodedRecipient, uint256 decodedAmount, bytes memory decodedFeeData) =
                    feeCodecHelper.decodePackedData(packedData);

                assertEq(recipient, decodedRecipient, "test_Fuzz_EncodePackedData::7");
                assertEq(amount, decodedAmount, "test_Fuzz_EncodePackedData::8");
                assertEq(feeData, decodedFeeData, "test_Fuzz_EncodePackedData::9");
            }

            {
                (address decodedRecipient, uint256 decodedAmount, bytes memory decodedFeeData) =
                    feeCodecHelper.decodePackedDataMemory(packedData);

                assertEq(recipient, decodedRecipient, "test_Fuzz_EncodePackedData::10");
                assertEq(amount, decodedAmount, "test_Fuzz_EncodePackedData::11");
                assertEq(feeData, decodedFeeData, "test_Fuzz_EncodePackedData::12");
            }
        }
    }

    function test_Fuzz_Revert_DecodePackedData(bytes memory feeData) public {
        uint256 length = feeData.length > 51 ? 51 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 52));
        feeCodecHelper.decodePackedData(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 52));
        feeCodecHelper.decodePackedDataMemory(feeData);
    }

    function test_Fuzz_DecodeFee(uint128 feeAmount, bool payInLink, bytes memory additionalData) public view {
        bytes memory feeData = abi.encodePacked(feeAmount, payInLink, additionalData);

        {
            (uint128 decodedFeeAmount, bool decodedPayInLink) = feeCodecHelper.decodeFee(feeData);

            assertEq(feeAmount, decodedFeeAmount, "test_Fuzz_DecodeFee::1");
            assertEq(payInLink, decodedPayInLink, "test_Fuzz_DecodeFee::2");
        }

        {
            (uint128 decodedFeeAmount, bool decodedPayInLink) = feeCodecHelper.decodeFeeMemory(feeData);

            assertEq(feeAmount, decodedFeeAmount, "test_Fuzz_DecodeFee::3");
            assertEq(payInLink, decodedPayInLink, "test_Fuzz_DecodeFee::4");
        }
    }

    function test_Fuzz_Revert_DecodeFee(bytes memory feeData) public {
        uint256 length = feeData.length > 16 ? 16 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 17));
        feeCodecHelper.decodeFee(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 17));
        feeCodecHelper.decodeFeeMemory(feeData);
    }

    function test_Fuzz_EncodeCCIP(uint128 maxFee, bool payInLink, uint32 gasLimit) public view {
        bytes memory feeData = feeCodecHelper.encodeCCIP(maxFee, payInLink, gasLimit);

        {
            (uint256 decodedMaxFee, bool decodedPayInLink, uint256 decodedGasLimit) = feeCodecHelper.decodeCCIP(feeData);

            assertEq(maxFee, decodedMaxFee, "test_Fuzz_EncodeCCIP::1");
            assertEq(payInLink, decodedPayInLink, "test_Fuzz_EncodeCCIP::2");
            assertEq(gasLimit, decodedGasLimit, "test_Fuzz_EncodeCCIP::3");
        }

        {
            (uint256 decodedMaxFee, bool decodedPayInLink, uint256 decodedGasLimit) =
                feeCodecHelper.decodeCCIPMemory(feeData);

            assertEq(maxFee, decodedMaxFee, "test_Fuzz_EncodeCCIP::4");
            assertEq(payInLink, decodedPayInLink, "test_Fuzz_EncodeCCIP::5");
            assertEq(gasLimit, decodedGasLimit, "test_Fuzz_EncodeCCIP::6");
        }
    }

    function test_Fuzz_Revert_DecodeCCIP(bytes memory feeData) public {
        uint256 length = feeData.length > 20 ? 20 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 21));
        feeCodecHelper.decodeCCIP(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 21));
        feeCodecHelper.decodeCCIPMemory(feeData);
    }

    function test_Fuzz_EncodeArbitrumL1toL2(uint128 maxSubmissionCost, uint32 maxGas, uint64 gasPriceBid) public view {
        maxGas =
            uint32(bound(maxGas, 0, gasPriceBid == 0 ? maxGas : (type(uint128).max - maxSubmissionCost) / gasPriceBid));

        bytes memory feeData = feeCodecHelper.encodeArbitrumL1toL2(maxSubmissionCost, maxGas, gasPriceBid);

        {
            (
                uint256 decodedFeeAmount,
                bool decodedPayInLink,
                uint256 decodedMaxSubmissionCost,
                uint256 decodedMaxGas,
                uint256 decodedGasPriceBid
            ) = feeCodecHelper.decodeArbitrumL1toL2(feeData);

            assertEq(
                maxSubmissionCost + uint128(gasPriceBid) * maxGas, decodedFeeAmount, "test_Fuzz_EncodeArbitrumL1toL2::1"
            );
            assertEq(false, decodedPayInLink, "test_Fuzz_EncodeArbitrumL1toL2::2");
            assertEq(maxSubmissionCost, decodedMaxSubmissionCost, "test_Fuzz_EncodeArbitrumL1toL2::3");
            assertEq(maxGas, decodedMaxGas, "test_Fuzz_EncodeArbitrumL1toL2::4");
            assertEq(gasPriceBid, decodedGasPriceBid, "test_Fuzz_EncodeArbitrumL1toL2::5");
        }

        {
            (
                uint256 decodedFeeAmount,
                bool decodedPayInLink,
                uint256 decodedMaxSubmissionCost,
                uint256 decodedMaxGas,
                uint256 decodedGasPriceBid
            ) = feeCodecHelper.decodeArbitrumL1toL2Memory(feeData);

            assertEq(
                maxSubmissionCost + uint128(gasPriceBid) * maxGas, decodedFeeAmount, "test_Fuzz_EncodeArbitrumL1toL2::6"
            );
            assertEq(false, decodedPayInLink, "test_Fuzz_EncodeArbitrumL1toL2::7");
            assertEq(maxSubmissionCost, decodedMaxSubmissionCost, "test_Fuzz_EncodeArbitrumL1toL2::8");
            assertEq(maxGas, decodedMaxGas, "test_Fuzz_EncodeArbitrumL1toL2::9");
            assertEq(gasPriceBid, decodedGasPriceBid, "test_Fuzz_EncodeArbitrumL1toL2::10");
        }
    }

    function test_Fuzz_Revert_DecodeArbitrumL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 28 ? 28 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 29));
        feeCodecHelper.decodeArbitrumL1toL2(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 29));
        feeCodecHelper.decodeArbitrumL1toL2Memory(feeData);
    }

    function test_Fuzz_EncodeOptimismL1toL2(uint32 l2Gas) public view {
        bytes memory feeData = feeCodecHelper.encodeOptimismL1toL2(l2Gas);

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink, uint256 decodedL2Gas) =
                feeCodecHelper.decodeOptimismL1toL2(feeData);

            assertEq(0, decodedFeeAmount, "test_Fuzz_EncodeOptimismL1toL2::1");
            assertEq(false, decodedPayInLink, "test_Fuzz_EncodeOptimismL1toL2::2");
            assertEq(l2Gas, decodedL2Gas, "test_Fuzz_EncodeOptimismL1toL2::3");
        }

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink, uint256 decodedL2Gas) =
                feeCodecHelper.decodeOptimismL1toL2Memory(feeData);

            assertEq(0, decodedFeeAmount, "test_Fuzz_EncodeOptimismL1toL2::4");
            assertEq(false, decodedPayInLink, "test_Fuzz_EncodeOptimismL1toL2::5");
            assertEq(l2Gas, decodedL2Gas, "test_Fuzz_EncodeOptimismL1toL2::6");
        }
    }

    function test_Fuzz_Revert_DecodeOptimismL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 20 ? 20 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 21));
        feeCodecHelper.decodeOptimismL1toL2(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 21));
        feeCodecHelper.decodeOptimismL1toL2Memory(feeData);
    }

    function test_Fuzz_EncodeBaseL1toL2(uint32 l2Gas) public view {
        bytes memory feeData = feeCodecHelper.encodeBaseL1toL2(l2Gas);

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink, uint256 decodedL2Gas) =
                feeCodecHelper.decodeBaseL1toL2(feeData);

            assertEq(0, decodedFeeAmount, "test_Fuzz_EncodeBaseL1toL2::1");
            assertEq(false, decodedPayInLink, "test_Fuzz_EncodeBaseL1toL2::2");
            assertEq(l2Gas, decodedL2Gas, "test_Fuzz_EncodeBaseL1toL2::3");
        }

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink, uint256 decodedL2Gas) =
                feeCodecHelper.decodeBaseL1toL2Memory(feeData);

            assertEq(0, decodedFeeAmount, "test_Fuzz_EncodeBaseL1toL2::4");
            assertEq(false, decodedPayInLink, "test_Fuzz_EncodeBaseL1toL2::5");
            assertEq(l2Gas, decodedL2Gas, "test_Fuzz_EncodeBaseL1toL2::6");
        }
    }

    function test_Fuzz_Revert_DecodeBaseL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 20 ? 20 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 21));
        feeCodecHelper.decodeBaseL1toL2(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 21));
        feeCodecHelper.decodeBaseL1toL2Memory(feeData);
    }

    function test_EncodeFraxFerryL1toL2() public view {
        bytes memory feeData = feeCodecHelper.encodeFraxFerryL1toL2();

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink) = feeCodecHelper.decodeFraxFerryL1toL2(feeData);

            assertEq(0, decodedFeeAmount, "test_EncodeFraxFerryL1toL2::1");
            assertEq(false, decodedPayInLink, "test_EncodeFraxFerryL1toL2::2");
        }

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink) = feeCodecHelper.decodeFraxFerryL1toL2Memory(feeData);

            assertEq(0, decodedFeeAmount, "test_EncodeFraxFerryL1toL2::3");
            assertEq(false, decodedPayInLink, "test_EncodeFraxFerryL1toL2::4");
        }
    }

    function test_Revert_DecodeFraxFerryL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 16 ? 16 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 17));
        feeCodecHelper.decodeFraxFerryL1toL2(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 17));
        feeCodecHelper.decodeFraxFerryL1toL2Memory(feeData);
    }

    function test_EncodeLineaL1toL2() public view {
        bytes memory feeData = feeCodecHelper.encodeLineaL1toL2();

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink) = feeCodecHelper.decodeLineaL1toL2(feeData);

            assertEq(decodedFeeAmount, 0, "test_EncodeLineaL1toL2::1");
            assertEq(false, decodedPayInLink, "test_EncodeLineaL1toL2::2");
        }

        {
            (uint256 decodedFeeAmount, bool decodedPayInLink) = feeCodecHelper.decodeLineaL1toL2Memory(feeData);

            assertEq(decodedFeeAmount, 0, "test_EncodeLineaL1toL2::3");
            assertEq(false, decodedPayInLink, "test_EncodeLineaL1toL2::4");
        }
    }

    function test_Revert_DecodeLineaL1toL2(bytes memory feeData) public {
        uint256 length = feeData.length > 16 ? 16 : feeData.length;

        assembly {
            mstore(feeData, length)
        }

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 17));
        feeCodecHelper.decodeLineaL1toL2(feeData);

        vm.expectRevert(abi.encodeWithSelector(FeeCodec.FeeCodecInvalidDataLength.selector, length, 17));
        feeCodecHelper.decodeLineaL1toL2Memory(feeData);
    }
}
