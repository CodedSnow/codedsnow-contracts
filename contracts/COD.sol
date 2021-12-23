// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/ICOD.sol";

contract COD is ERC20, ICOD {
    /* ========== STATE VARIABLES ========== */
    uint256 internal _initialSupply;

    address private founder;
    address private treasury;

    bool private distributed;

    /* ========== CONSTRUCTOR ========== */
    constructor()
    ERC20("CodedSnow", "COD", 9) {
        founder = msg.sender;
        _initialSupply = 56000 * (10^decimals());
    }

    /* ========== MODIFIERS ========== */
    modifier onlyFounder {
        require(msg.sender == founder, "Founder only.");
        _;
    }

    modifier onlyTreasury {
        require(msg.sender != address(0), "Treasury zero address.");
        require(msg.sender == treasury, "Founder only.");
        _;
    }

    /* ========== FOUNDER ONLY ========== */
    function setTreasury(address account_) external onlyFounder {
        require(treasury == address(0), "Treasury can only be set once.");
        treasury = account_;
    }

    function distSupply(address _presale, address _team) external onlyFounder {
        require(distributed == false, "Already distributed supply.");

        distributed = true;

        // 40.000 for presale + 10.000 for pool
        _mint(_presale, 50000 * (10^decimals()));
        // 6.000 for team/maintenance
        _mint(_team, 6000);
    }

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyTreasury {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyTreasury {
        _burn(account_, amount_);
    }

    /* ========== GLOBAL ========== */
    function initialSupply() public view returns (uint256) {
        return _initialSupply;
    }
}