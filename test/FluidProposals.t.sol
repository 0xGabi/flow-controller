// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.27;


import "forge-std/Test.sol";

import {FluidProposals} from "src/FluidProposals.sol";
import {SetupScript} from "src/SetupScript.sol";
import {ABDKMath64x64} from "src/libraries/ABDKMath64x64.sol";
import {OwnableUpgradeable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
import {ConvictionVoting, ProposalStatus} from "../src/interfaces/IConvictionVoting.sol";

contract FluidProposalsTest is SetupScript, Test {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);

    address fp = 0x856d17D5323794A7Db0ba17f59d4B88FD402D321;
    address user = 0x2F9e113434aeBDd70bB99cB6505e1F726C578D6d;
    // address user = 0x5CfAdf589a694723F9Ed167D647582B3Db3b33b3;
    address owner;

    // fork env
    string GNOSIS_RPC_URL = vm.envOr("GNOSIS_RPC_URL", string("https://rpc.gnosis.gateway.fm"));

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true; // deploys contracts without any checks whatsoever
    }

    function setUp() public {
        bytes memory constructorArgs = abi.encode(uint256(2));
        address implementation = setUpContract("FluidProposals", constructorArgs);
        // if in fork mode create and select fork
        vm.createSelectFork(GNOSIS_RPC_URL);

        fluidProposals = FluidProposals(fp);
        owner = fluidProposals.owner();
        // setUpContracts();
        vm.startPrank(owner);
        upgradeProxy(fp, implementation);
        uint256[] memory proposals = new uint256[](1);
        proposals[0] = 171;
        vm.stopPrank();
        (,,,,,,,, address submmiter,) = ConvictionVoting(cv).getProposal(proposals[0]);

        vm.prank(submmiter);
        fluidProposals.removeProposal(171);
        // owner = OwnableUpgradeable(address()).owner();

        // labels
        vm.label(owner, "owner");
        vm.label(user, "user");
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function assertOsmoticParam(int128 _poolParam, uint256 _param) public {
        assertEq(_poolParam.mulu(1e18), _param);
    }

    function testEnv() public  {
        assertEq(address(fluidProposals.cv()), cv, "cv");
        assertEq(address(fluidProposals.superfluid()), superfluid, "superfluid");
        assertEq(address(fluidProposals.token()), superToken, "superToken");
        assertEq(fluidProposals.wrapAmount(), WRAP_AMOUNT, "WRAP_AMOUNT");
        assertEq(fluidProposals.ceilingBps(), CEILING_BSP,"CEILING_BSP");
    }

    function testRemoveProposal() public {
        vm.startPrank(user);
        // fluidProposals.registerProposal(150, user);
        // fluidProposals.activateProposal(150);
        fluidProposals.removeProposal(150);
        vm.stopPrank();
    }

    function testSync_() public {

        vm.startPrank(user);
        fluidProposals.sync();
        vm.warp(block.timestamp+ 1 days);
        fluidProposals.sync();
        vm.stopPrank();
    }
    function testSetWrapAmount(uint256 _amount) public {
        vm.prank(owner);
        fluidProposals.setWrapAmount(_amount);

        assertEq(fluidProposals.wrapAmount(), _amount);
    }
    
    function testFailSetWrapAmountNotAuthorized(uint256 _amount) public {
        vm.prank(notAuthorized);

        fluidProposals.setWrapAmount(_amount);
    }

    function testSetCeilingBps(uint256 _ceilingBps) public {
        vm.assume(_ceilingBps <= 500);

        vm.prank(owner);
        fluidProposals.setCeilingBps(_ceilingBps);
        
        // require(fluidProposals.ceilingBps() == _ceilingBps);
        assertEq(fluidProposals.ceilingBps(), _ceilingBps);
    }

    function testFailSetCeilingBps(uint256 _ceilingBps) public {
        vm.assume(_ceilingBps > 500);

        vm.prank(owner);
        fluidProposals.setCeilingBps(_ceilingBps);
    }
}
