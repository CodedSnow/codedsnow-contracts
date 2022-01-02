// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "../interfaces/IAuthority.sol";

abstract contract AuthGuard {
    /* ========== VARIABLES ========== */
    string private constant UNAUTHORIZED = "UNAUTHORIZED"; // save gas

    IAuthority private authority;

    /* ========== Constructor ========== */
    constructor(address _authority) {
        authority = IAuthority(_authority);
    }

    /* ========== GOVERNOR ONLY ========== */
    function setAuthority(address _newAuthority) external onlyGovernor {
        authority = IAuthority(_newAuthority);
    }

    /* ========== MODIFIERS ========== */
    modifier onlyGovernor() {
        require(msg.sender == authority.governor(), UNAUTHORIZED);
        _;
    }

    modifier onlyGuardian() {
        require(msg.sender == authority.guardian(), UNAUTHORIZED);
        _;
    }

    modifier onlyTreasury() {
        require(msg.sender == authority.treasury(), UNAUTHORIZED);
        _;
    }

    modifier onlyShares() {
        require(msg.sender == authority.shares(), UNAUTHORIZED);
        _;
    }

    modifier onlyStaking() {
        require(msg.sender == authority.staking(), UNAUTHORIZED);
        _;
    }

    modifier forEpoch() {
        require(msg.sender == authority.shares() || msg.sender == authority.staking(), UNAUTHORIZED);
        _;
    }
}