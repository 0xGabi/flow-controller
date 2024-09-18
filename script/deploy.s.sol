// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {SetupScript} from "src/SetupScript.sol";

import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";
import {FluidProposals} from "src/FluidProposals.sol";

import "forge-std/console.sol";

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
/*
# Anvil Dry-Run (make sure it is running):
US_DRY_RUN=true forge script deploy --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -vvvv --ffi

# Broadcast:
forge script deploy --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -vvv --broadcast --ffi*/

contract deploy is SetupScript {
    function run() external {
//        UPGRADE_SCRIPTS_DRY_RUN = true;

        // uncommenting this line would mark the two contracts as having a compatible storage layout
        // isUpgradeSafe[31337][0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0][0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9] = true; // prettier-ignore
        // isUpgradeSafe[31337][0x5FbDB2315678afecb367f032d93F642f64180aa3][0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0] = true;
        isUpgradeSafe[100][0x1867Ccde8aF324205f42C9cbB5075282D89F5002][0x34A1D3fff3958843C43aD80F30b94c510645C316] = true;
        // uncomment with current timestamp to confirm deployments on mainnet for 15 minutes or always allow via (block.timestamp)
        // mainnetConfirmation = 1700616755;
        mainnetConfirmation = block.timestamp;

        // will run `vm.startBroadcast();` if ffi is enabled
        // ffi is required for running storage layout compatibility checks
        // if ffi is disabled, it will enter "dry-run" and
        // run `vm.startPrank(tx.origin)` instead for the script to be consistent
//        upgradeScriptsBroadcast();

        vm.startBroadcast();
        // run the setup scripts
//        setUpContracts();
//        UPGRADE_SCRIPTS_ATTACH_ONLY = true;

        bytes memory constructorArgs = abi.encode(uint256(2));
        address implementation = setUpContract("FluidProposals", constructorArgs);

        console.log("FluidProposals new implementation: %s", implementation);
        // encodes function call
        bytes memory initCall = abi.encodeCall(FluidProposals.initialize2,());

        string memory contractName = registeredContractName[block.chainid][implementation];
        string memory keyOrContractName = string.concat(contractName, "Proxy");
        address _proxy = loadLatestDeployedAddress(keyOrContractName);

        console.log("Proxy address: %s", _proxy);

        UUPSUpgrade proxy = UUPSUpgrade(_proxy);

        console.log("Upgrading to %s", implementation);
        console.log("Init call");
        console.logBytes(initCall);

//        proxy.upgradeToAndCall(implementation, initCall);

        fluidProposals = FluidProposals(address(proxy));
        // we don't need broadcast from here on
        vm.stopBroadcast();

        // run an "integration test"
//         integrationTest();

        // console.log and store these in `deployments/{chainid}/deploy-latest.json` (if not in dry-run)
        storeLatestDeployments();
    }
}
