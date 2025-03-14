// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/adapters/BridgeAdapter.sol";
import "../../contracts/adapters/ArbitrumLegacyAdapterL1toL2.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockReceiver.sol";

contract ArbitrumLegacyAdapterL1toL2Test is Test {
    MockReceiver public receiver;
    ArbitrumLegacyAdapterL1toL2 public adapter;

    MockERC20 public l1Token;
    MockGatewayRouter public gatewayRouter;

    address public l1TokenGateway = makeAddr("l1TokenGateway");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        receiver = new MockReceiver();

        l1Token = new MockERC20("L1 Token", "L1T", 18);
        gatewayRouter = new MockGatewayRouter(address(l1Token), l1TokenGateway);

        adapter = new ArbitrumLegacyAdapterL1toL2(address(gatewayRouter), address(l1Token), address(receiver));

        receiver.setAdapter(address(adapter));
    }

    function test_Constructor() public {
        adapter = new ArbitrumLegacyAdapterL1toL2(address(gatewayRouter), address(l1Token), address(receiver)); // to fix coverage

        assertEq(address(adapter.L1_GATEWAY_ROUTER()), address(gatewayRouter), "test_Constructor::1");
        assertEq(address(adapter.L1_TOKEN()), address(l1Token), "test_Constructor::2");
        assertEq(address(adapter.L1_TOKEN_GATEWAY()), address(l1TokenGateway), "test_Constructor::3");
        assertEq(address(adapter.DELEGATOR()), address(receiver), "test_Constructor::4");
    }

    function test_Revert_Constructor() public {
        vm.expectRevert(ArbitrumLegacyAdapterL1toL2.ArbitrumLegacyAdapterInvalidParameters.selector);
        adapter = new ArbitrumLegacyAdapterL1toL2(address(0), address(l1Token), address(receiver));

        vm.expectRevert(ArbitrumLegacyAdapterL1toL2.ArbitrumLegacyAdapterInvalidParameters.selector);
        adapter = new ArbitrumLegacyAdapterL1toL2(address(gatewayRouter), address(0), address(receiver));

        vm.expectRevert(IBridgeAdapter.BridgeAdapterInvalidParameters.selector);
        adapter = new ArbitrumLegacyAdapterL1toL2(address(gatewayRouter), address(l1Token), address(0));
    }

    function test_Fuzz_sendToken(uint256 amount, uint128 maxSubmissionCost, uint32 maxGas, uint64 gasPriceBid) public {
        maxGas =
            uint32(bound(maxGas, 0, gasPriceBid == 0 ? maxGas : (type(uint128).max - maxSubmissionCost) / gasPriceBid));

        bytes memory feeData = FeeCodec.encodeArbitrumL1toL2(maxSubmissionCost, maxGas, gasPriceBid);
        uint256 msgValue = maxSubmissionCost + uint128(gasPriceBid) * maxGas;

        vm.deal(address(receiver), msgValue);
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        assertEq(gatewayRouter.msgValue(), msgValue, "test_Fuzz_sendToken::1");
        assertEq(
            gatewayRouter.msgData(),
            abi.encodeWithSelector(
                IArbitrumL1GatewayRouter.outboundTransfer.selector,
                l1Token,
                recipient,
                amount,
                maxGas,
                gasPriceBid,
                abi.encode(maxSubmissionCost, new bytes(0))
            ),
            "test_Fuzz_sendToken::2"
        );
        assertEq(
            IERC20(l1Token).allowance(address(receiver), address(l1TokenGateway)), amount, "test_Fuzz_sendToken::3"
        );
    }

    function test_Fuzz_Revert_SendToken(
        address msgSender,
        uint256 amount,
        uint128 maxSubmissionCost,
        uint32 maxGas,
        uint64 gasPriceBid
    ) public {
        maxGas =
            uint32(bound(maxGas, 0, gasPriceBid == 0 ? maxGas : (type(uint128).max - maxSubmissionCost) / gasPriceBid));

        bytes memory feeData = abi.encodePacked(uint128(0), true, uint32(0), uint64(0));

        vm.expectRevert(ArbitrumLegacyAdapterL1toL2.ArbitrumLegacyAdapterL1toL2InvalidFeeToken.selector);
        receiver.sendToken(uint64(0), recipient, amount, feeData);

        feeData = FeeCodec.encodeArbitrumL1toL2(maxSubmissionCost, maxGas, gasPriceBid);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(msgSender);
        adapter.sendToken(uint64(0), recipient, amount, feeData);

        vm.expectRevert(IBridgeAdapter.BridgeAdapterOnlyDelegatedByDelegator.selector);
        vm.prank(address(receiver));
        adapter.sendToken(uint64(0), recipient, amount, feeData);
    }
}

contract MockGatewayRouter {
    mapping(address => address) public l1TokenToGateway;
    bytes public msgData;
    uint256 public msgValue;

    constructor(address l1Token_, address l1TokenGateway_) {
        l1TokenToGateway[l1Token_] = l1TokenGateway_;
    }

    function outboundTransfer(address, address, uint256, uint256, uint256, bytes memory)
        external
        payable
        returns (bytes memory)
    {
        msgData = msg.data;
        msgValue = msg.value;

        return abi.encode(bytes32(0));
    }

    // Force foundry to ignore this contract from coverage
    function test() public pure {}
}
