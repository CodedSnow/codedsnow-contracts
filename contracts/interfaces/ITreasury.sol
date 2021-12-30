// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface ITreasury {
    function canBuyBond() external view returns (bool);

    function canSellBond() external view returns (bool);

    function calcBonus() external view returns (uint256 bonusCod_);

    function assetToNative(address _tokenIn, uint256 _amountIn) external view returns (uint256 nativeAmount);

    function buyBond(uint256 _amount) external;

    function sellBond(uint256 _amount) external;

    function lastEpoch() external view returns (uint256);

    function nextEpoch() external view returns (uint256);

    function totalEpochs() external view returns (uint256);

    function getEpochPrice() external view returns (uint256 codPrice_);
}
