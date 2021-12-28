// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/ICOD.sol";
import "./types/AccessControlled.sol";

contract COD is ERC20, ICOD, AccessControlled {
    /* ========== STATE VARIABLES ========== */
    uint256 internal _initialSupply;
    bool private distributed;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _authority)
        ERC20("CodedSnow", "COD", 9)
        AccessControlled(IAuthority(_authority))
    {
        _initialSupply = 56000 * (10**9);
    }

    /* ========== GOVERNOR ONLY ========== */
    function distSupply(address _presale, address _team) external onlyGovernor {
        require(distributed == false, "Already distributed supply.");

        distributed = true;

        // 40.000 for presale + 10.000 for pool
        _mint(_presale, 50000 * (10**9));
        // 6.000 for team/maintenance
        _mint(_team, 6000 * (10**9));
    }

    /* ========== TREASURY ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyTreasury {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyTreasury {
        _burn(account_, amount_);
    }

    /* ========== GLOBAL ========== */
    function initialSupply() external view returns (uint256) {
        return _initialSupply;
    }
}
