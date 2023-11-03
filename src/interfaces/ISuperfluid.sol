// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISuperToken.sol";

contract Superfluid {
    function upgrade(SuperToken _token, uint256 amount) external {}

    function createFlow(SuperToken _token, address _receiver, int96 _flowRate, bytes memory _description) external {}

    function updateFlow(SuperToken _token, address _receiver, int96 _flowRate, bytes memory _description) external {}

    function deleteFlow(SuperToken _token, address _receiver) external {}
}
