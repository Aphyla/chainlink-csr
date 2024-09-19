// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../script/lido/LidoDeploy.s.sol";

contract fork_LidoDeployScriptTest is Test, LidoParameters {
    LidoDeployScript public script;

    function setUp() public {
        script = new LidoDeployScript();
        script.setUp();
    }

    function test_Deploy() public {
        script.run();
    }
}
