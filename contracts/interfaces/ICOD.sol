// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./IERC20.sol";

interface ICod is IERC20 {
    function initialSupply() external view returns (uint256);

    /* ========== GOVERNOR ONLY ========== */
    function distSupply(address _presale) external;

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external;

    function burn(address account_, uint256 amount_) external;
}
