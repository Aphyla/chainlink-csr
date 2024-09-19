// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../script/frax/FraxDeploy.s.sol";

contract fork_FraxDeployScriptTest is Test, FraxParameters {
    FraxDeployScript public script;

    function setUp() public {
        script = new FraxDeployScript();
        script.setUp();
    }

    function test_Deploy() public {
        script.run();
    }
}
