// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ICOD.sol";
import "./interfaces/IsCOD.sol";
import "./interfaces/ITreasury.sol";

contract Vault {
    /* ========== STATE VARIABLES ========== */
    ICOD private immutable cod;
    IsCOD private immutable sCod;
    ITreasury private immutable treasury;

    struct Unlock {
        address receiver;
        uint256 amount;
        uint256 claimable;
    }
    Unlock[] public unlocks;

    /* ========== CONSTRUCTOR ========== */
    constructor(
        address _cod,
        address _sCod,
        address _treasury
    ) {
        cod = ICOD(_cod);
        sCod = IsCOD(_sCod);
        treasury = ITreasury(_treasury);
    }

    /* ========== INTERACTIONS ========== */
    function stake(
        address _to,
        uint256 _amount /*cod value*/
    ) external {
        require(cod.balanceOf(msg.sender) >= _amount, "Insufficient funds");

        // Send funds to treasury
        cod.transferFrom(msg.sender, address(treasury), _amount);

        uint256 codAmount = (_amount * sCod.exchValue()) / (10**9);
        sCod.mint(_to, codAmount);

        // TODO:
        // Keep track of bought exch-rate
        // Call event
    }

    function unstake(address _to) external {
        uint256 sCodBalance = sCod.balanceOf(msg.sender);
        require(sCodBalance > 0, "Insufficient funds");

        sCod.burn(msg.sender, sCodBalance);

        // TODO:
        // Calculate the amount based on bought exch-rate
        // Add to unlocks
        // Call event
    }

    function claim() external returns (bool) {
        // Loop over unlocks
        // Check for unlock on your address
        // Check if eligible
        // Allocate funds
        // Otherwise continue
        // Return whether there was atleast one successful withdrawal
    }
}
