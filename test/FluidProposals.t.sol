// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.13;

import "forge-std/Test.sol";

import "src/FluidProposals.sol";
import {ABDKMath64x64} from "src/libraries/ABDKMath64x64.sol";

import "./interfaces/IACL.sol";

contract FluidProposalsTest is Test {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    FluidProposals fluidProposals;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);
    address voting = 0x5F137364b1f6ad84a2863D5dcD27f4841c077E53;
    address creator = 0x5CfAdf589a694723F9Ed167D647582B3Db3b33b3;

    // rinkeby test env
    address cv = 0x06B35a5E6799Ab2FFdC383E81490cd72c983d5a5;
    address superfluid = 0xFD0c006C16395dE18D38eFbcbD85b53d68366235;
    address superToken = 0xE166aa0a466d7d012940c872AA0e0cd74c7bc7e9;

    IACL acl = IACL(0x5164aE80218773F06a5455585ef31781453AEc4C);
    bytes32 constant MANAGE_STREAMS_ROLE =
        0x56c3496db27efc6d83ab1a24218f016191aab8835d442bc0fa8502f327132cbe;

    // flow settings
    uint256 DECAY = 999999900000000000;
    uint256 MAX_RATIO = 7716049382;
    uint256 WEIGHT = 25000000000000000;

    function setUp() public {
        fluidProposals = new FluidProposals(
            cv,
            superfluid,
            superToken,
            DECAY,
            MAX_RATIO,
            WEIGHT
        );

        // assign permission
        vm.prank(voting);
        acl.grantPermission(
            address(fluidProposals),
            superfluid,
            MANAGE_STREAMS_ROLE
        );

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function testActivateProposal() public {
        vm.prank(creator);
        fluidProposals.activateProposal(2, sender);
    }

    function testActivateProposalAndSync() public {
        vm.prank(creator);
        fluidProposals.activateProposal(2, sender);
        fluidProposals.sync();
    }

    function testDeactivateProposal() public {
        vm.prank(creator);
        fluidProposals.activateProposal(2, sender);
        fluidProposals.deactivateProposal(2);
    }

    function testActivateTwoProposalsAndSync() public {
        vm.startPrank(creator);
        fluidProposals.activateProposal(2, sender);
        fluidProposals.activateProposal(3, sender);
        vm.stopPrank();
        fluidProposals.sync();
    }

    function testActivateTwoProposalsAndSync() public {
        vm.startPrank(creator);
        fluidProposals.activateProposal(2, sender);
        fluidProposals.activateProposal(3, sender);
        fluidProposals.sync();
    }

    // function testActivateTwoProposalsAndSync() public {
    //     fluidProposals.activateProposal(2, sender);
    //     fluidProposals.activateProposal(3, sender);
    //     fluidProposals.sync();
    // }
}
