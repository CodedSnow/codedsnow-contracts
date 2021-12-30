// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./AuthGuard.sol";

contract Epoch is AuthGuard {
    /* ========== STATE VARIABLES ========== */
    uint256 private _epochTime; // Time between epochs (e.g. 8 hours) (in seconds)
    uint256 private _lastEpoch; // Unix epoch
    uint256 private _totalEpochs; // Total amount of epochs

    /* ========== CONSTRUCTOR ========== */
    constructor(
        uint256 _interval,
        uint256 _currentTime,
        address _authority
    ) AuthGuard(IAuthority(_authority)) {
        _epochTime = _interval;
        _lastEpoch = _currentTime;
    }

    /* ========== MODIFIERS ========== */
    modifier checkEpoch() {
        // How many epochs did we miss?
        uint256 missed = (block.timestamp - lastEpoch()) / _epochTime;
        if (missed > 0) {
            _lastEpoch = block.timestamp;
            _totalEpochs + missed;
        }
        _;
    }
    
    /* ========== VIEW FUNCTIONS ========== */
    function lastEpoch() public view returns (uint256) {
        return _lastEpoch;
    }

    function nextEpoch() public view returns (uint256) {
        return _lastEpoch + _epochTime;
    }

    function totalEpochs() public view returns (uint256) {
        return _totalEpochs;
    }

    function setEpoch() public onlyTreasury {

    }

    /* ========== GOVERNOR ONLY ========== */
    function setEpochInterval(uint256 _interval) external onlyGovernor {
        _epochTime = _interval;
    }
}
