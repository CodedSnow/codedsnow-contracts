// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/ICBond.sol";
import "./types/AuthGuard.sol";

contract CBond is ERC20, ICBond, AuthGuard {
    /* ========== CONSTRUCTOR ========== */
    constructor(address _auth)
        ERC20("Bonded COD", "CBOND", 9)
        AuthGuard(_auth)
    {}

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyTreasury {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyTreasury {
        _burn(account_, amount_);
    }
}
