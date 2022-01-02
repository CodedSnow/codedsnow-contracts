// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./types/AuthGuard.sol";

contract Tomb is ERC20, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    uint256 public initialSupply;
    bool private distributed;

    /**
     * @notice Constructs the TOMB ERC-20 contract.
     */
    constructor(address _auth) ERC20("TOMB", "TOMB", 18) AuthGuard(_auth) {
        _mint(msg.sender, 1 ether);
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

        _mint(_presale, 151000 * 10e18);
        _mint(_airdrop, 9000 * 10e18);
    }
}
