// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./types/AuthGuard.sol";

contract TShare is ERC20, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    uint256 public initialSupply;
    bool private distributed;

    constructor(address _auth) ERC20("CodedSnow Share", "CSHARE", 18) AuthGuard(_auth) {
        // Birth Pericles => 495 BC
        // Led athens for => 32 years
        // Total pSupply = 495*32 = 15840

        // Birth Herodotus => 484 BC
        // The 9 histories => 9
        // Total hSupply = 484*9 = 4356

        // Supply = 3 * (15840 + 4356) = 3 * (20196) = 60588
        initialSupply = 60588 * (10e18);
    }

    function distSupply(address _treasury, address _presale) external onlyGovernor {
        require(distributed == false, "Already distributed supply");
        distributed = true;

        _mint(_treasury, 4760 * 10e18); // DAO
        _mint(msg.sender, 2813 * 10e18); // Team
        _mint(_presale, 53015 * 10e18); // Presale
    }
}
