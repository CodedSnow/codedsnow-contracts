
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./IERC20.sol";

interface ITomb is IERC20 {
    function initialSupply() external view returns (uint256);

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external;

    function burn(address account_, uint256 amount_) external;
}