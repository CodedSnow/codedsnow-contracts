// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IAuthority {
    /* ========== EVENTS ========== */
    event GovernorPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event GuardianPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event TreasuryPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event SharesPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event StakingPushed(address indexed from, address indexed to, bool _effectiveImmediately);

    event GovernorPulled(address indexed from, address indexed to);
    event GuardianPulled(address indexed from, address indexed to);
    event TreasuryPulled(address indexed from, address indexed to);
    event SharesPulled(address indexed from, address indexed to);
    event StakingPulled(address indexed from, address indexed to);

    /* ========== VIEW ========== */
    function governor() external view returns (address);

    function guardian() external view returns (address);

    function treasury() external view returns (address);

    function shares() external view returns (address);

    function staking() external view returns (address);
}
