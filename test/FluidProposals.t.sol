// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.13;

import "forge-std/Test.sol";

import {FluidProposals} from "src/FluidProposals.sol";
import {SetupScript} from "src/SetupScript.sol";
import {ABDKMath64x64} from "src/libraries/ABDKMath64x64.sol";

import "./interfaces/IACL.sol";

contract FluidProposalsTest is SetupScript {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);
    address voting = 0x5F137364b1f6ad84a2863D5dcD27f4841c077E53;
    address creator = 0x5CfAdf589a694723F9Ed167D647582B3Db3b33b3;

    IACL acl = IACL(0x5164aE80218773F06a5455585ef31781453AEc4C);
    bytes32 constant MANAGE_STREAMS_ROLE = 0x56c3496db27efc6d83ab1a24218f016191aab8835d442bc0fa8502f327132cbe;

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true; // deploys contracts without any checks whatsoever
    }

    function setUp() public {
        setUpContracts();

        // assign permission
        vm.prank(voting);
        acl.grantPermission(address(fluidProposals), superfluid, MANAGE_STREAMS_ROLE);

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function testIntegration() public view {
        require(fluidProposals.owner() == msg.sender);

        require(keccak256(abi.encode(fluidProposals.cv())) == keccak256(abi.encode(cv)));
        require(keccak256(abi.encode(fluidProposals.superfluid())) == keccak256(abi.encode(superfluid)));
        require(keccak256(abi.encode(fluidProposals.token())) == keccak256(abi.encode(superToken)));
    }
}
