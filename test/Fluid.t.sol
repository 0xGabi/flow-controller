// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/FluidProposals.sol";
import {SetupScript} from "../src/SetupScript.sol";

contract AFluidProposalTest is Test, SetupScript{
    FluidProposals c;
    
    address fp = 0x77af4F40D013670a9285E6EBA6774Ff746df6aF0;
    address creator = 0x5CfAdf589a694723F9Ed167D647582B3Db3b33b3;

    uint256 GNOSIS_FORK_BLOCK_NUMBER = 28687355; // Mime token factory deployment block
    // uint256 GNOSIS_FORK_BLOCK_NUMBER = 24440055; // Mime token factory deployment block
    // string GNOSIS_RPC_URL = vm.envOr("GNOSIS_RPC_URL", string("https://rpc.gnosis.gateway.fm"));
    string GNOSIS_RPC_URL = vm.envOr("GNOSIS_RPC_URL", string("https://rpc.ankr.com/gnosis"));

    constructor() Test() SetupScript() {
        console.log("constructor");
        UPGRADE_SCRIPTS_BYPASS = true;
    }
    function setUp() public {
        // run the setup scripts
        vm.createSelectFork(GNOSIS_RPC_URL);
        console.log("before FluidProposals");
        vm.startPrank(creator);
        setUpContracts();
        console.log("after FluidProposals");
        vm.stopPrank();
   }


    function testSyncTokens() public {
        console.log("testSyncTokens");
        vm.prank(creator);
        fluidProposals.syncSupertoken();
    }
}