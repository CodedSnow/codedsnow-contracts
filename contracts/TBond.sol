// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./types/AuthGuard.sol";

contract TBond is ERC20, AuthGuard {
    constructor(address _auth) ERC20("TBOND", "TBOND", 18) AuthGuard(_auth) {}

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyTreasury {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyTreasury {
        _burn(account_, amount_);
    }
}
