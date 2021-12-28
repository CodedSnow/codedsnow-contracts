// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

// Interface for ERC20 DAI contract
interface IDAI {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function balanceOf(address) external view returns (uint256);
}
