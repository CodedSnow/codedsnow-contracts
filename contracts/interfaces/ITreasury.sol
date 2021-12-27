// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface ITreasury {
    /* ========== ONLY GOVERNOR ========== */
    function grantAirdrop(address _to) external;

    /* ========== VAULT ========== */
    function updateAlloc(uint256 _amount) external;
    function rewardAlloc() external view returns (uint256);

    /* ========== INTERACTIONS ========== */
    function placeOrder(address _to, uint256 _daiAmount) external;
    function redeemOrder(uint256 _id) external;
}