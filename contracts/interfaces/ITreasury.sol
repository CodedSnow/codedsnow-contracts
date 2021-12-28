// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./IUniswapV2Pair.sol";
import "./IERC20.sol";

interface ITreasury {
    event OrderCreated(
        uint256 indexed id,
        address receiver,
        uint256 bondId,
        uint256 codAmount,
        uint256 expiry
    );
    event OrderClaimed(uint256 indexed id, address receiver, uint256 amount);

    /* ========== ONLY GUARDIAN ========== */
    function addBond(
        address _princinple,
        address _swapAddr,
        uint256 _maxDebt,
        uint256 _currentDebt,
        uint256 _vestingTerm,
        uint256 _minPayout,
        uint256 _maxPayout
    ) external returns (uint256 _id);

    function deprecateBond(uint256 _id) external;

    /* ========== VAULT ========== */
    function updateAlloc(uint256 _amount) external;

    function rewardAlloc() external view returns (uint256);

    /* ========== INTERACTIONS ========== */
    function bond(
        uint256 _bondId,
        address _to,
        uint256 _amount
    ) external returns (uint256);

    function claim(uint256 _orderId) external;

    function tokenPrice(address _swapAddr, IERC20 _principal)
        external
        view
        returns (uint256 price_);
}
