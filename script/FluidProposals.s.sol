// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/FluidProposals.sol";

contract FluidProposalsScript is Script {
    // gnosis env
    address cv = 0x0B21081C6F8b1990f53FC76279Cc41ba22D7AFE2;
    address superfluid = 0x0C7bfB0A57f3223b9Cf1d3C2ba2618481714A35D;
    address superToken = 0xc0712524B39323eb2437E69226b261d928629dC8;

    // flow settings, check https://www.desmos.com/calculator/zce2ygj7bd for more details
    uint256 DECAY = 999999197747000000; // 10 days (864000 seconds) to reach 50% of targetRate, check https://www.desmos.com/calculator/twlx3u8e9u for mor details
    uint256 MAX_RATIO = 19290123456; // 5% of Common Pool per month = Math.floor(0.05e18 / (30 * 24 * 60 * 60))
    uint256 MIN_STAKE_RATIO = 25000000000000000; // 2.5% of Total Support = the minimum stake to start receiving funds

    function setUp() public {}

    function run() public {
        vm.broadcast();

        new FluidProposals(
            cv,
            superfluid,
            superToken,
            DECAY,
            MAX_RATIO,
            MIN_STAKE_RATIO
        );

        vm.stopBroadcast();
    }
}
