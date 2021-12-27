// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ICOD.sol";
import "./interfaces/IsCOD.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IAuthority.sol";

contract Vault {
    /* ========== STATE VARIABLES ========== */
    ICOD private immutable cod;
    IsCOD private immutable sCod;
    ITreasury private immutable treasury;

    uint256 private exchValue;
    uint private lastRecalc;

    struct Unlock {
        address receiver;
        uint256 amount;
        uint claimable;
    }
    Unlock[] public unlocks;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _cod, address _sCod, address _authority) {
        cod = ICOD(_cod);
        sCod = IsCOD(_sCod);
        treasury = ITreasury(IAuthority(_authority).treasury());

        // First manual (re)base
        exchValue = 10**9; // 1 cod = 1 sCod 
        lastRecalc = block.timestamp;
    }

    /* ========== MODIFIERS ========== */
    modifier handleRecalc() {
        // How many recalculations did we miss?
        uint256 missed = (block.timestamp - lastRecalc) / 8 hours;
        if (missed > 0) {
            uint256 incr = missed * ((treasury.rewardAlloc() / 100 * 80) / 6480);
            treasury.updateAlloc(incr);

            exchValue += incr;
            lastRecalc = block.timestamp;
        }
        _;
    }

    /* ========== INTERACTIONS ========== */
    function stake(address _to, uint256 _amount/*cod value*/) external {
        require(cod.balanceOf(msg.sender) >= _amount, "Not enough funds.");

        // Send funds to treasury
        cod.transferFrom(msg.sender, address(treasury), _amount);

        uint256 codAmount = (_amount * exchValue) / (10**9);
        sCod.mint(_to, codAmount);

        // TODO: 
        // Keep track of bought exch-rate
        // Call event
    }

    function unstake(address _to) external {
        uint256 sCodBalance = sCod.balanceOf(msg.sender);
        require(sCodBalance > 0, "Nothing to unstake.");

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