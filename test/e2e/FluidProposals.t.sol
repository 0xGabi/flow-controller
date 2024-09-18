// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/FluidProposals.sol";

import {OwnableUpgradeable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
contract FluidProposalsE2E is Test {
    FluidProposals c;

    address cv = vm.envAddress("CONVICTION_VOTING_APP");
    address superfluid = vm.envAddress("SUPERFLUID_APP");
    address superToken = vm.envAddress("SUPER_TOKEN");
    
    address fp = 0x856d17D5323794A7Db0ba17f59d4B88FD402D321;
    // address fp = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address user = 0x5CfAdf589a694723F9Ed167D647582B3Db3b33b3;
    address owner;


    string GNOSIS_RPC_URL = vm.envOr("GNOSIS_RPC_URL", string("https://rpc.ankr.com/gnosis"));

    function setUp() public {
        // run the setup scripts
        vm.createSelectFork(GNOSIS_RPC_URL);
        
        c = FluidProposals(fp);

        owner = OwnableUpgradeable(address(fp)).owner();

        vm.label(owner, "owner");
        vm.label(user, "user");
        vm.label(fp, "fp");
        vm.label(cv, "cv");
        vm.label(superfluid, "superfluid");
        vm.label(superToken, "superToken");
   }


    function testSyncTokens() public {
        vm.prank(user);
        c.syncSupertoken();
    }

    function testSync_() public {
        vm.prank(user);
        c.sync();
    }
}