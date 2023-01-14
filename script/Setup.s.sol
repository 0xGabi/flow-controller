// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";
import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";

import {FluidProposals} from "../src/FluidProposals.sol";

contract SetupScript is UpgradeScripts {
    FluidProposals fluidProposals;

    // gnosis env
    address cv = 0x0B21081C6F8b1990f53FC76279Cc41ba22D7AFE2;
    address superfluid = 0x0C7bfB0A57f3223b9Cf1d3C2ba2618481714A35D;
    address superToken = 0xc0712524B39323eb2437E69226b261d928629dC8;

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

    /// @dev override using forge's built-in create2 deployer (only works for specific chains, or: use your own!)
    function deployCode(bytes memory code) internal override returns (address addr) {
        uint256 salt = 0x1234;

        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
        }
    }

    function setUpContracts() internal {
        // encodes constructor call
        bytes memory constructorArgs = abi.encode(uint256(1));
        address implementation = setUpContract("FluidProposals", constructorArgs);

        // encodes function call
        bytes memory initCall =
            abi.encodeCall(FluidProposals.initialize, (cv, superfluid, superToken, DECAY, MAX_RATIO, MIN_STAKE_RATIO));
        address proxy = setUpProxy(implementation, initCall);

        fluidProposals = FluidProposals(proxy);
    }

    function integrationTest() internal view {
        require(fluidProposals.owner() == msg.sender);

        // require(keccak256(abi.encode(nft.name())) == keccak256(abi.encode("My NFT")));
        // require(keccak256(abi.encode(nft.symbol())) == keccak256(abi.encode("NFTX")));
    }
}
