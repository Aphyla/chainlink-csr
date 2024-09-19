// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract ScriptHelper is Script {
    function _getProxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }

    function _getProxyImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT))));
    }

    function _predictContractAddress(address account, uint256 deltaNonce) internal view returns (address) {
        uint256 nonce = vm.getNonce(account) + deltaNonce;
        return vm.computeCreateAddress(account, nonce);
    }
}
