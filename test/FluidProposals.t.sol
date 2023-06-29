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
    address creator = 0x5CfAdf589a694723F9Ed167D647582B3Db3b33b3;

    // fork env
    uint256 GNOSIS_FORK_BLOCK_NUMBER = 28687355; // Mime token factory deployment block
    string GNOSIS_RPC_URL = vm.envOr("GNOSIS_RPC_URL", string("https://rpc.gnosis.gateway.fm"));

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true; // deploys contracts without any checks whatsoever
    }

    function setUp() public {
        // if in fork mode create and select fork
        vm.createSelectFork(GNOSIS_RPC_URL, GNOSIS_FORK_BLOCK_NUMBER);

        fluidProposals = FluidProposals(0x6705B54dC554c781B834FCc5Ae18402127DD88ba);

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function testEnv() public view {
        require(keccak256(abi.encode(fluidProposals.cv())) == keccak256(abi.encode(cv)));
        require(keccak256(abi.encode(fluidProposals.superfluid())) == keccak256(abi.encode(superfluid)));
        require(keccak256(abi.encode(fluidProposals.token())) == keccak256(abi.encode(superToken)));
    }

    function testRemove() public {
        fluidProposals.sync();
    }
}
