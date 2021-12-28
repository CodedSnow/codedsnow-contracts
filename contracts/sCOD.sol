// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./types/ERC20.sol";
import "./interfaces/IsCOD.sol";
import "./types/AccessControlled.sol";
import "./interfaces/ITreasury.sol";

contract sCOD is ERC20, IsCOD, AccessControlled {
    ITreasury private immutable treasury;

    uint256 private _exchValue;
    uint256 private _lastRecalc;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _authority)
        ERC20("CodedSnow", "COD", 9)
        AccessControlled(IAuthority(_authority))
    {
        treasury = ITreasury(IAuthority(_authority).treasury());

        _exchValue = 10**9; // 1 cod = 1 sCod
        _lastRecalc = block.timestamp;
    }

    /* ========== VAULT ONLY ========== */
    function mint(address account_, uint256 amount_) external onlyVault {
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyVault {
        _burn(account_, amount_);
    }

    // Happens every 7 days
    modifier handleRecalc() {
        // How many recalculations did we miss?
        uint256 missed = (block.timestamp - _lastRecalc) / 7 days;
        if (missed > 0) {
            // Incremental value for this recalc
            uint256 incr = missed * ((treasury.rewardAlloc() / 100) * 80);
            treasury.updateAlloc(incr);

            _exchValue += incr;
            _lastRecalc = block.timestamp;
        }
        _;
    }

    function exchValue() external view returns (uint256) {
        return _exchValue;
    }
}
