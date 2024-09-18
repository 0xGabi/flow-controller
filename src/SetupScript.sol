// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";
import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";

import {FluidProposals} from "./FluidProposals.sol";

import "forge-std/console.sol";

contract SetupScript is UpgradeScripts {
    FluidProposals fluidProposals;

    address cv = vm.envAddress("CONVICTION_VOTING_APP");
    address superfluid = vm.envAddress("SUPERFLUID_APP");
    address superToken = vm.envAddress("SUPER_TOKEN");

    uint256 WRAP_AMOUNT = 100 ether;
    uint256 CEILING_BSP = 250; // 2.5% of Common Pool expresed as Basis Points

    // flow settings, check https://www.desmos.com/calculator/zce2ygj7bd for more details
    uint256 DECAY = 999999197747000000; // 10 days (864000 seconds) to reach 50% of targetRate, check https://www.desmos.com/calculator/twlx3u8e9u for mor details
    uint256 MAX_RATIO = 19290123456; // 5% of Common Pool per month = Math.floor(0.05e18 / (30 * 24 * 60 * 60))
    uint256 MIN_STAKE_RATIO = 25000000000000000; // 2.5% of Total Support = the minimum stake to start receiving funds


    /// @dev using OZ's ERC1967Proxy
    function getDeployProxyCode(address implementation, bytes memory initCall)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initCall));
    }

    /// @dev using OZ's UUPSUpgradeable function call
    function upgradeProxy(address proxy, address newImplementation) internal override {
        UUPSUpgradeable(proxy).upgradeTo(newImplementation);
    }

    // /// @dev override using forge's built-in create2 deployer (only works for specific chains, or: use your own!)
    // function deployCode(bytes memory code) internal override returns (address addr) {
    //     uint256 salt = 0x1234;

    //     assembly {
    //         addr := create2(0, add(code, 0x20), mload(code), salt)
    //     }
    // }

    function setUpContracts() internal {
        // encodes constructor call
        bytes memory constructorArgs = abi.encode(uint256(2));
        address implementation = setUpContract("FluidProposals", constructorArgs);

        console.log("FluidProposals new implementation: %s", implementation);
        // encodes function call
        bytes memory initCall =
            abi.encodeCall(FluidProposals.initialize, (cv, superfluid, superToken, DECAY, MAX_RATIO, MIN_STAKE_RATIO, WRAP_AMOUNT, CEILING_BSP));
        address proxy = setUpProxy(implementation, initCall);

        fluidProposals = FluidProposals(proxy);
    }

    function integrationTest() internal view {
        require(keccak256(abi.encode(fluidProposals.cv())) == keccak256(abi.encode(cv)),"cv");
        require(keccak256(abi.encode(fluidProposals.superfluid())) == keccak256(abi.encode(superfluid)),"superfluid");
        require(keccak256(abi.encode(fluidProposals.token())) == keccak256(abi.encode(superToken)), "superToken");
        require(fluidProposals.owner() == msg.sender,"owner");
    }
}
