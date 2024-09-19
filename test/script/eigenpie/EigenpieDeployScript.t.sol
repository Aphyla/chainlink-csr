// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../script/eigenpie/EigenpieDeploy.s.sol";

contract fork_EigenpieDeployScriptTest is Test, EigenpieParameters {
    EigenpieDeployScript public script;

    function setUp() public {
        script = new EigenpieDeployScript();
        script.setUp();
    }

    function test_Deploy() public {
        script.run();
    }
}
