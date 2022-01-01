// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface ITreasury {
    event BoughtBond(address indexed to, uint256 _amount);
    event SoldBond(address indexed to, uint256 _amount);

    function lastPrice() external view returns (uint256);

    function targetPrice() external view returns (uint256);

    function rewardCeiling() external view returns (uint256);

    function rewardRatio() external view returns (uint256);

    function maxDebtRatio() external view returns (uint256);

    function calcBonus() external view returns (uint256 bonusCod_);

    function buyBond(uint256 _amount) external;

    function sellBond(uint256 _amount) external;
}
