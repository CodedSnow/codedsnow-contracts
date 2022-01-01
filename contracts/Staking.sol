// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/IEpoch.sol";
import "./interfaces/ICShare.sol";
import "./interfaces/ICod.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IAuthority.sol";
import "./types/AuthGuard.sol";

contract Staking is AuthGuard {
    IEpoch private immutable epoch;
    ICShare private immutable cshare;
    ICod private immutable cod;
    ITreasury private immutable treasury;

    /* ========== DATA STRUCTURES ========== */
    struct Stake {
        uint256 stakeAmount;
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
        uint256 epochTimerStart;
    }

    /* ========== STATE VARIABLES ========== */
    mapping(address => Stake) public stakes;
    uint256[] public rpsHistory;

    uint256 public withdrawLockupEpochs;
    uint256 public rewardLockupEpochs;

    /* ========== CONSTRUCTOR =============== */
    constructor(
        address _epoch,
        address _cshare,
        address _cod,
        address _auth
    ) AuthGuard(_auth) {
        epoch = IEpoch(_epoch);
        cshare = ICShare(_cshare);
        cod = ICod(_cod);
        treasury = ITreasury(IAuthority(_auth).treasury());

        rpsHistory.push(1); // Genesis snapshot

        withdrawLockupEpochs = 6; // Lock for 6 epochs (30h) before release withdraw
        rewardLockupEpochs = 3; // Lock for 3 epochs (15h) before release claimReward
    }

    /* ========== EVENTS ========== */
    event Initialized(address indexed executor, uint256 at);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(address indexed user, uint256 reward);

    /* ========== MODIFIERS =============== */
    modifier updateReward() {
        // First update the epoch (if needed)
        treasury.updateEpoch();
        // Update the reward
        Stake memory seat = stakes[msg.sender];
        seat.rewardEarned = earned(msg.sender);
        seat.lastSnapshotIndex = getLastRPSIndex();
        stakes[msg.sender] = seat;
        _;
    }

    /* ========== GOVERNANCE ========== */
    function setLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external onlyGuardian {
        require(_withdrawLockupEpochs >= _rewardLockupEpochs && _withdrawLockupEpochs <= 56, "Out of range"); // <= 2 week
        withdrawLockupEpochs = _withdrawLockupEpochs;
        rewardLockupEpochs = _rewardLockupEpochs;
    }

    /* ========== VIEW FUNCTIONS ========== */
    function getLastRPSIndex() private view returns (uint256) {
        return rpsHistory.length - 1;
    }

    function getLastRPS() private view returns (uint256) {
        return rpsHistory[getLastRPSIndex()];
    }

    function getLastRPSOf(address _user) private view returns (uint256) {
        return rpsHistory[stakes[_user].lastSnapshotIndex];
    }

    function canWithdraw(address _user) external view returns (bool) {
        return stakes[_user].epochTimerStart + withdrawLockupEpochs <= epoch.currentEpoch();
    }

    function canClaimReward(address _user) external view returns (bool) {
        return stakes[_user].epochTimerStart + rewardLockupEpochs <= epoch.currentEpoch();
    }

    /* ========== GET FUNCTIONS ========== */
    function earned(address _acc) public view returns (uint256) {
        uint256 latestRPS = getLastRPS();
        uint256 storedRPS = getLastRPS();

        return cshare.balanceOf(_acc) * (latestRPS - storedRPS) / 1e9 + stakes[_acc].rewardEarned;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function stake(uint256 _amount) external updateReward {
        require(_amount > 0, "Invalid amount");
        
        // Remove funds
        cshare.transferFrom(msg.sender, address(this), _amount);
        stakes[msg.sender].stakeAmount += _amount;
        stakes[msg.sender].epochTimerStart = epoch.currentEpoch(); // reset timer

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external updateReward {
        // Check
        require(_amount > 0, "Invalid amount");
        require(stakes[msg.sender].stakeAmount > 0, "Not enough staked");
        require(stakes[msg.sender].epochTimerStart + withdrawLockupEpochs <= epoch.currentEpoch(), "Still in withdraw lockup");
        // Effect
        stakes[msg.sender].stakeAmount -= _amount;
        // Interaction
        cshare.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claimReward() external updateReward {
        uint256 reward = stakes[msg.sender].rewardEarned;
        if (reward > 0) {
            // Check
            require(stakes[msg.sender].epochTimerStart + rewardLockupEpochs <= epoch.currentEpoch(), "Still in reward lockup");
            // Effect
            stakes[msg.sender].rewardEarned = 0;
            stakes[msg.sender].epochTimerStart = epoch.currentEpoch(); // reset timer
            // Interaction
            cod.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function allocateSeigniorage(uint256 _amount) external onlyGuardian {
        // Create & add new snapshot
        uint256 prevRPS = getLastRPS();
        // a + (b / c) => 1 + (493 / 12345) = 1.03993...
        uint256 nextRPS = prevRPS + (_amount * 1e9 / cshare.totalSupply());

        rpsHistory.push(nextRPS);

        cod.transferFrom(msg.sender, address(this), _amount);
        emit RewardAdded(msg.sender, _amount);
    }

}