// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/ICod.sol";
import "./types/AuthGuard.sol";

contract Cod is ERC20, ICod, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    uint256 public initialSupply; // Comes with getter function
    
    bool private distributed;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _auth)
        ERC20("COD", "COD", 9)
        AuthGuard(_auth)
    {
        // Birth Pericles => 495 BC
        // Led athens for => 32 years
        // Total pSupply = 495*32 = 15840

        // Birth Herodotus => 484 BC
        // The 9 histories => 9
        // Total hSupply = 484*9 = 4356

        // Supply = 3 * (49532 + 4849) = 6 * (20196) = 121176
        initialSupply = 121176 * (10**9);
    }

    /* ========== GOVERNOR ONLY ========== */
    function distSupply(address _presale) external onlyGovernor {
        require(distributed == false, "Already distributed supply");
        distributed = true;

        _mint(_presale, initialSupply);
    }

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyTreasury {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyTreasury {
        _burn(account_, amount_);
    }
}
