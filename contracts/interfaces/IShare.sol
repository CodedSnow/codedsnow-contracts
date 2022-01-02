// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IERC20.sol";

interface IShare is IERC20 {
    function initialSupply() external view returns (uint256);
}
