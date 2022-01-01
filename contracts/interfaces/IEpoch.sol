// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IEpoch {
    event EpochUpdated(uint256 _lastEpoch);

    function updateEpoch() external;

    function missedEpochs() external view returns (uint256);

    function nextEpoch() external view returns (uint256);
}
