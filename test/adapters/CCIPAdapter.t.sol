// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "../../contracts/adapters/CCIPAdapter.sol";
import "../../contracts/interfaces/ICCIPSenderUpgradeable.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockCCIPRouter.sol";
import "../mocks/MockReceiver.sol";

contract CCIPAdapterTest is Test {
    MockReceiver public receiver;
    CCIPAdapter public adapter;

    MockERC20 public l1Token;
    MockCCIPRouter public ccipRouter;
    MockERC20 public token;

    uint256 public constant LINK_FEE = 1e18;
    uint256 public constant NATIVE_FEE = 0.01e18;

    address public recipient = makeAddr("recipient");

    function setUp() public {
        receiver = new MockReceiver();

        l1Token = new MockERC20("L1 Token", "L1T", 18);
        ccipRouter = new MockCCIPRouter(address(0), LINK_FEE, NATIVE_FEE);

        adapter = new CCIPAdapter(address(l1Token), address(ccipRouter), address(receiver));

        receiver.setAdapter(address(adapter));

        vm.label(address(ccipRouter), "ccipRouter");
        vm.label(address(l1Token), "l1Token");
        vm.label(address(receiver), "receiver");
        vm.label(address(adapter), "adapter");
    }

    function test_Constructor() public {
        adapter = new CCIPAdapter(address(l1Token), address(ccipRouter), address(receiver)); // to fix coverage

        assertEq(address(adapter.CCIP_ROUTER()), address(ccipRouter), "test_Constructor::1");
        assertEq(address(adapter.LINK_TOKEN()), address(0), "test_Constructor::2");
        assertEq(address(adapter.L1_TOKEN()), address(l1Token), "test_Constructor::3");
        assertEq(address(adapter.DELEGATOR()), address(receiver), "test_Constructor::4");
    }

    function test_Fuzz_sendToken(uint64 sourceChainSelector, uint256 amount, uint256 maxFee, uint256 maxGas) public {
        maxFee = bound(maxFee, NATIVE_FEE, type(uint256).max);

        bytes memory feeData = FeeCodec.encodeCCIP(maxFee, false, maxGas);

        l1Token.mint(address(receiver), amount);

        vm.deal(address(receiver), maxFee);
        receiver.sendToken(sourceChainSelector, recipient, amount, feeData);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(l1Token), amount: amount});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(recipient),
            data: new bytes(0),
            tokenAmounts: tokenAmounts,
            feeToken: address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: maxGas}))
        });

        assertEq(ccipRouter.value(), NATIVE_FEE, "test_Fuzz_sendToken::1");
        assertEq(ccipRouter.data(), abi.encode(sourceChainSelector, message), "test_Fuzz_sendToken::2");
    }

    function test_Fuzz_Revert_sendToken(uint256 maxFee, uint256 maxGas) public {
        vm.expectRevert(CCIPAdapter.CCIPAdapterPayInLinkNotSupported.selector);
        receiver.sendToken(0, address(0), 0, FeeCodec.encodeCCIP(0, true, 0));

        maxFee = bound(maxFee, 0, NATIVE_FEE - 1);

        vm.expectRevert(
            abi.encodeWithSelector(ICCIPSenderUpgradeable.CCIPSenderExceedsMaxFee.selector, NATIVE_FEE, maxFee)
        );
        receiver.sendToken(0, address(0), 1, FeeCodec.encodeCCIP(maxFee, false, maxGas));
    }
}
