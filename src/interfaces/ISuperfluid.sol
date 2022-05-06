// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./ISuperToken.sol";

contract Superfluid {
    function createFlow(
        ISuperToken _token,
        address _receiver,
        int96 _flowRate,
        bytes memory _description
    ) external {}

    function updateFlow(
        ISuperToken _token,
        address _receiver,
        int96 _flowRate,
        bytes memory _description
    ) external {}

    function deleteFlow(ISuperToken _token, address _receiver) external {}
}
