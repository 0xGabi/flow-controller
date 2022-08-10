// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/FluidProposals.sol";

contract FluidProposalsScript is Script {
    // gnosis env
    address cv = 0x0B21081C6F8b1990f53FC76279Cc41ba22D7AFE2;
    address superfluid = 0xae19d972C8FE568B3e0D12Ad4A814816f8F3c0c2;
    address superToken = 0xc0712524B39323eb2437E69226b261d928629dC8;

    // flow settings
    uint256 DECAY = 999999900000000000;
    uint256 MAX_RATIO = 7716049382;
    uint256 WEIGHT = 25000000000000000;

    function setUp() public {}

    function run() public {
        vm.broadcast();

        new FluidProposals(
            cv,
            superfluid,
            superToken,
            DECAY,
            MAX_RATIO,
            WEIGHT
        );

        vm.stopBroadcast();
    }
}
