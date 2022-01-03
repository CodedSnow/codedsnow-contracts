// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./types/AuthGuard.sol";

contract Cod is ERC20, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    uint256 public initialSupply;
    bool private distributed;

    constructor(address _auth) ERC20("CodedSnow", "COD", 18) AuthGuard(_auth) {
        // 15000 to presale
        // 9000 to airdrop
        initialSupply = 24000 * 10e18;
    }

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyTreasury {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyTreasury {
        _burn(account_, amount_);
    }

    /* ========== GOVERNER ONLY ========== */
    function distSupply(address _presale, address _airdrop) external onlyGovernor {
        require(distributed == false, "Already distributed supply");
        distributed = true;

        _mint(_presale, 15000 * 10e18);
        _mint(_airdrop, 9000 * 10e18);
    }
}
