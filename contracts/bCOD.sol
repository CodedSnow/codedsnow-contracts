// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/IbCOD.sol";
import "./types/AuthGuard.sol";

contract bCOD is ERC20, IbCOD, AuthGuard {
    /* ========== CONSTRUCTOR ========== */
    constructor(address _authority)
        ERC20("Bonded CodedSnow", "bCOD", 9)
        AuthGuard(IAuthority(_authority))
    {}

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyTreasury {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyTreasury {
        _burn(account_, amount_);
    }
}
