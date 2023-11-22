// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.17;

import "forge-std/Test.sol";

import {FluidProposals} from "src/FluidProposals.sol";
import {SetupScript} from "src/SetupScript.sol";
import {ABDKMath64x64} from "src/libraries/ABDKMath64x64.sol";

contract FluidProposalsTest is SetupScript, Test {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);

    // fork env
    string GNOSIS_RPC_URL = vm.envOr("GNOSIS_RPC_URL", string("https://rpc.gnosis.gateway.fm"));

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true; // deploys contracts without any checks whatsoever
    }

    function setUp() public {
        // if in fork mode create and select fork
        vm.createSelectFork(GNOSIS_RPC_URL);

        setUpContracts();

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function assertOsmoticParam(int128 _poolParam, uint256 _param) public {
        assertEq(_poolParam.mulu(1e18), _param);
    }

    function testEnv() public view {
        require(address(fluidProposals.cv()) == cv);
        require(address(fluidProposals.superfluid()) == superfluid);
        require(address(fluidProposals.token()) == superToken);
        require(fluidProposals.wrapAmount() == WRAP_AMOUNT);
        require(fluidProposals.ceilingBps() == CEILING_BSP);
    }

    function testSetWrapAmount(uint256 _amount) public {
        fluidProposals.setWrapAmount(_amount);

        require(fluidProposals.wrapAmount() == _amount);
    }
    
    function testFailSetWrapAmountNotAuthorized(uint256 _amount) public {
        vm.prank(notAuthorized);

        fluidProposals.setWrapAmount(_amount);
    }

    function testSetCeilingBps(uint256 _ceilingBps) public {
        vm.assume(_ceilingBps <= 500);

        fluidProposals.setCeilingBps(_ceilingBps);

        require(fluidProposals.ceilingBps() == _ceilingBps);
    }

    function testFailSetCeilingBps(uint256 _ceilingBps) public {
        vm.assume(_ceilingBps > 500);

        fluidProposals.setCeilingBps(_ceilingBps);
    }
}
