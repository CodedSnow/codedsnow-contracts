// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/IsCOD.sol";

contract sCOD is ERC20, IsCOD {
    /* ========== STATE VARIABLES ========== */
    address private founder;
    address private vault;

    /* ========== CONSTRUCTOR ========== */
    constructor() ERC20("CodedSnow", "COD", 9) {
        founder = msg.sender;
    }

    /* ========== MODIFIERS ========== */
    modifier onlyFounder {
        require(msg.sender == founder, "Founder only.");
        _;
    }

    modifier onlyVault {
        require(msg.sender != address(0), "Vault zero address.");
        require(msg.sender == vault, "Founder only.");
        _;
    }

    /* ========== FOUNDER ONLY ========== */
    function setVault(address account_) external onlyFounder {
        require(vault == address(0), "Vault can only be set once.");
        
        vault = account_;
    }

    /* ========== VAULT ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyVault {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyVault {
        _burn(account_, amount_);
    }
}