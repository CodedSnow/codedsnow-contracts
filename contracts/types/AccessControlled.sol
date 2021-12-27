// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "../interfaces/IAuthority.sol";

abstract contract AccessControlled {
    /* ========== EVENTS ========== */
    event AuthorityUpdated(IAuthority indexed authority);

    /* ========== VARIABLES ========== */
    IAuthority public authority;

    string constant private UNAUTHORIZED = "UNAUTHORIZED"; // save gas

    /* ========== Constructor ========== */
    constructor(IAuthority _authority) {
        authority = _authority;
        emit AuthorityUpdated(_authority);
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

    modifier onlyVault() {
        require(msg.sender == authority.vault(), UNAUTHORIZED);
        _;
    }
    
    /* ========== GOV ONLY ========== */
    function setAuthority(IAuthority _newAuthority) external onlyGovernor {
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }
}