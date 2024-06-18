// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BridgeAdapter} from "./BridgeAdapter.sol";
import {FeeCodec} from "../libraries/FeeCodec.sol";
import {IOptimismL1ERC20TokenBridge} from "../interfaces/IOptimismL1ERC20TokenBridge.sol";

contract OptimismLegacyAdapterL1toL2 is BridgeAdapter {
    using SafeERC20 for IERC20;

    error OptimismLegacyAdapterL1toL2InvalidFeeAmount(uint256 expectedFeeAmount, uint256 feeAmount);

    address public immutable L1_ERC20_BRIDGE;
    address public immutable L1_TOKEN;
    address public immutable L2_TOKEN;

    constructor(address l1ERC20Bridge, address delegator) BridgeAdapter(delegator) {
        L1_ERC20_BRIDGE = l1ERC20Bridge;
        L1_TOKEN = IOptimismL1ERC20TokenBridge(l1ERC20Bridge).l1Token();
        L2_TOKEN = IOptimismL1ERC20TokenBridge(l1ERC20Bridge).l2Token();
    }

    function _sendToken(address to, uint256 amount, bytes memory feeData) internal override {
        (uint256 feeAmount, uint32 l2Gas) = FeeCodec.decodeOptimismL1toL2(feeData);

        if (feeAmount != 0) revert OptimismLegacyAdapterL1toL2InvalidFeeAmount(feeAmount, 0);

        IERC20(L1_TOKEN).forceApprove(L1_ERC20_BRIDGE, amount);

        IOptimismL1ERC20TokenBridge(L1_ERC20_BRIDGE).depositERC20To(L1_TOKEN, L2_TOKEN, to, amount, l2Gas, new bytes(0));
    }
}
