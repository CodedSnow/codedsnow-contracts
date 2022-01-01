// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "../interfaces/IEpoch.sol";
import "../types/AuthGuard.sol";

contract Epoch is IEpoch, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    uint256 private _epochTime; // Time between epochs (e.g. 8 hours) (in seconds)
    uint256 private _lastEpoch; // Unix epoch

    /* ========== CONSTRUCTOR + SETUP ========== */
    constructor(uint256 _currentTime, address _auth) AuthGuard(_auth) {
        _epochTime = 18000; // Every 5 hours
        _lastEpoch = _currentTime;
    }

    /* ========== PRIV ONLY ========== */
    function setEpochInterval(uint256 _interval) external onlyGuardian {
        _epochTime = _interval;
    }

    function updateEpoch() external forEpoch {
        _lastEpoch = block.timestamp;

        emit EpochUpdated(block.timestamp);
    }

    /* ========== PUBLIC ========== */
    function missedEpochs() public view returns (uint256) {
        return (block.timestamp - _lastEpoch) / _epochTime; // Lovely trunication
    }

    /* ========== EXTERNAL ========== */
    function nextEpoch() external view returns (uint256) {
        return _lastEpoch + _epochTime;
    }
}
