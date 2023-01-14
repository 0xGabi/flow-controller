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

    // gnosis test env
    address cv = 0x16c87B344199C51119Ec7Df2364391C35895a7A4;
    address superfluid = 0x0C7bfB0A57f3223b9Cf1d3C2ba2618481714A35D;
    address superToken = 0xc0712524B39323eb2437E69226b261d928629dC8;

    IACL acl = IACL(0x5164aE80218773F06a5455585ef31781453AEc4C);
    bytes32 constant MANAGE_STREAMS_ROLE = 0x56c3496db27efc6d83ab1a24218f016191aab8835d442bc0fa8502f327132cbe;

    // flow settings, check https://www.desmos.com/calculator/zce2ygj7bd for more details
    uint256 DECAY = 999999197747000000; // 10 days (864000 seconds) to reach 50% of targetRate, check https://www.desmos.com/calculator/twlx3u8e9u for mor details
    uint256 MAX_RATIO = 19290123456; // 5% of Common Pool per month = Math.floor(0.05e18 / (30 * 24 * 60 * 60))
    uint256 MIN_STAKE_RATIO = 25000000000000000; // 2.5% of Total Support = the minimum stake to start receiving funds

    function setUp() public {
        fluidProposals = new FluidProposals(
            cv,
            superfluid,
            superToken,
            DECAY,
            MAX_RATIO,
            MIN_STAKE_RATIO
        );

        // assign permission
        vm.prank(voting);
        acl.grantPermission(address(fluidProposals), superfluid, MANAGE_STREAMS_ROLE);

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }
}
