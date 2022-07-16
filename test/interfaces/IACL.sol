// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IACL {
    function grantPermission(
        address _entity,
        address _app,
        bytes32 _role
    ) external;
}
