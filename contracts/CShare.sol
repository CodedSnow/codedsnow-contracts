// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/ICShare.sol";
import "./types/AuthGuard.sol";

contract CShare is ERC20, ICShare, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    bool private distributed;

    uint256 public initialSupply;

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

        // Supply = 3 * (49532 + 4849) = 3 * (20196) = 60588
        initialSupply = 60588 * (10**9);
    }

    /* ========== GOVERNOR ONLY ========== */
    function distSupply(address _treasury, address _team, address _presale) external onlyGovernor {
        require(distributed == false, "Already distributed supply");
        distributed = true;

        // Mint the tokens 
        _mint(_treasury, 4760 * (10**9));
        _mint(_team, 4220 * (10**9));
        _mint(_presale, 51608 * (10**9));
    }
}
