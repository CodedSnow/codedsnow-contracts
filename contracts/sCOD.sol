// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/IsCOD.sol";
import "./types/AccessControlled.sol";

contract sCOD is ERC20, IsCOD, AccessControlled {
    /* ========== CONSTRUCTOR ========== */
    constructor(address _authority)
    ERC20("CodedSnow", "COD", 9)
    AccessControlled(IAuthority(_authority)) {}

    /* ========== VAULT ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyVault {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyVault {
        _burn(account_, amount_);
    }

    // TODO: Handle recalc here
}