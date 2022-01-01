// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./IERC20.sol";

interface ICShare is IERC20 {
    function initialSupply() external view returns (uint256);

    /* ========== GOVERNOR ONLY ========== */
    function distSupply(address _treasury, address _team, address _presale) external;
}
