// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ScriptHelper is Script {
    address DEAD_ADDRESS = address(0xdead);

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

    function _checkRole(address target, bytes32 role, address oldAdmin, address newAdmin, string memory message)
        internal
        view
    {
        if (newAdmin == address(0)) {
            if (!AccessControl(target).hasRole(role, oldAdmin)) revert(string.concat(message, ":1"));
        } else {
            if (!AccessControl(target).hasRole(role, newAdmin)) revert(string.concat(message, ":2"));
            if (oldAdmin != newAdmin) {
                if (AccessControl(target).hasRole(role, oldAdmin)) revert(string.concat(message, ":3"));
            }
        }
    }

    function _checkOwner(address target, address oldAdmin, address newAdmin, string memory message) internal view {
        if (Ownable(target).owner() != (newAdmin == address(0) ? oldAdmin : newAdmin)) revert(message);
    }
}
