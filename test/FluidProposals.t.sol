// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "src/FluidProposals.sol";
import {ABDKMath64x64} from "src/libraries/ABDKMath64x64.sol";

contract FluidProposalsTest is Test {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    FluidProposals fluidProposals;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);

    // rinkeby test env
    address cv = 0x06B35a5E6799Ab2FFdC383E81490cd72c983d5a5;
    address superfluid = 0xFD0c006C16395dE18D38eFbcbD85b53d68366235;
    address superToken = 0xE166aa0a466d7d012940c872AA0e0cd74c7bc7e9;

    // flow settings
    uint256 DECAY = 999999900000000000;
    uint256 MAX_RATIO = 7716049382;
    uint256 WEIGHT = 25000000000000000;

    function setUp() public {
        fluidProposals = new FluidProposals(cv, superfluid, superToken, DECAY, MAX_RATIO, WEIGHT);

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function testSomething() public {}
}
