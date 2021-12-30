// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/IAuthority.sol";
import "./types/AuthGuard.sol";

contract Authority is IAuthority, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    address public override governor;
    address public override guardian;
    address public override treasury;

    address public newGovernor;
    address public newGuardian;
    address public newTreasury;

    /* ========== Constructor ========== */
    constructor(address _governor) AuthGuard(IAuthority(address(this))) {
        governor = _governor;
        emit GovernorPushed(address(0), governor, true);
    }

    /* ========== GOV ONLY ========== */
    function pushGovernor(address _newGovernor, bool _effectiveImmediately)
        external
        onlyGovernor
    {
        if (_effectiveImmediately) governor = _newGovernor;
        newGovernor = _newGovernor;
        emit GovernorPushed(governor, newGovernor, _effectiveImmediately);
    }

    function pushGuardian(address _newGuardian, bool _effectiveImmediately)
        external
        onlyGovernor
    {
        if (_effectiveImmediately) guardian = _newGuardian;
        newGuardian = _newGuardian;
        emit GuardianPushed(guardian, newGuardian, _effectiveImmediately);
    }

    function pushTreasury(address _newTreasury, bool _effectiveImmediately)
        external
        onlyGovernor
    {
        if (_effectiveImmediately) treasury = _newTreasury;
        newTreasury = _newTreasury;
        emit TreasuryPushed(treasury, newTreasury, _effectiveImmediately);
    }

    /* ========== PENDING ROLE ONLY ========== */
    function pullGovernor() external {
        require(msg.sender == newGovernor, "!newGovernor");
        emit GovernorPulled(governor, newGovernor);
        governor = newGovernor;
    }

    function pullGuardian() external {
        require(msg.sender == newGuardian, "!newGuard");
        emit GuardianPulled(guardian, newGuardian);
        guardian = newGuardian;
    }

    function pullTreasury() external {
        require(msg.sender == newTreasury, "!newTreasury");
        emit TreasuryPulled(treasury, newTreasury);
        treasury = newTreasury;
    }
}
