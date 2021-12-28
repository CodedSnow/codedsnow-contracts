// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/IAuthority.sol";
import "./types/AccessControlled.sol";

contract Authority is IAuthority, AccessControlled {
    /* ========== STATE VARIABLES ========== */
    address public override governor;
    address public override guardian;
    address public override treasury;
    address public override vault;

    address public newGovernor;
    address public newGuardian;
    address public newTreasury;
    address public newVault;

    /* ========== Constructor ========== */
    constructor(address _governor) AccessControlled(IAuthority(address(this))) {
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

    function pushVault(address _newVault, bool _effectiveImmediately)
        external
        onlyGovernor
    {
        if (_effectiveImmediately) vault = _newVault;
        newVault = _newVault;
        emit VaultPushed(vault, newVault, _effectiveImmediately);
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

    function pullVault() external {
        require(msg.sender == newVault, "!newVault");
        emit VaultPulled(vault, newVault);
        vault = newVault;
    }
}
