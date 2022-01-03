// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IStaking {
    /* ========== VIEW FUNCTIONS ========== */
    function latestSnapshotIndex() external view returns (uint256);

    function getLastSnapshotIndexOf(address _acc) external view returns (uint256);

    function canWithdraw(address _acc) external view returns (bool);

    function canClaimReward(address _acc) external view returns (bool);

    /* ========== GETTER FUNCTIONS ========== */
    function rewardPerShare() external view returns (uint256);

    function earned(address _acc) external view returns (uint256);

    /* ========== MUTATIVE FUNCTIONS ========== */
    function stake(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function exit() external;

    function claimReward() external;

    /* ========== ONLY TREASURY ========== */
    function allocateSeigniorage(uint256 _amount) external;
}
