// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ICod.sol";
import "./interfaces/ICShare.sol";

contract Presale {
    /* ========== STATE VARIABLES ========== */
    address private immutable cod;
    address private immutable cshare;
    address private immutable treasury;

    bool private didEnd;
    uint256 public endDate;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _cod, address _cshare, address _treasury, uint256 _endDate) {
        endDate = _endDate;

        cod = _cod;
        cshare = _cshare;
        treasury = _treasury;
    }

    /* ========== MODIFIERS ========== */
    modifier handleEnd() {
        require(didEnd == false, "Presale ended");
        if (endDate <= block.timestamp) {
            didEnd = true;
            // TODO: Move to liquidity pools
        } else {
          _;  
        }
    }

    // Buy Cod with MATIC
    function buyCod() public payable handleEnd {
        uint256 codAmount = msg.value * 60 / 100; // 60%
        require(codAmount <= ICod(cod).balanceOf(address(this)), "Presale-Cod depleted");

        ICod(cod).transfer(msg.sender, codAmount);
    }

    // Buy CShare with MATIC
    function buyCShare() public payable handleEnd {
        uint256 cshareAmount = msg.value * 75 / 100; // 75%
        require(cshareAmount <= ICShare(cshare).balanceOf(address(this)), "Presale-CShare depleted");

        ICShare(cshare).transfer(msg.sender, cshareAmount); 
    }
}
