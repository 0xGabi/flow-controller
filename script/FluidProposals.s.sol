// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/FluidProposals.sol";

contract FluidProposalsScript is Script {
    // rinkeby test env
    address cv = 0x06B35a5E6799Ab2FFdC383E81490cd72c983d5a5;
    address superfluid = 0xFD0c006C16395dE18D38eFbcbD85b53d68366235;
    address superToken = 0xE166aa0a466d7d012940c872AA0e0cd74c7bc7e9;

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
