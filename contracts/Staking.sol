// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./interfaces/IStaking.sol";
import "./types/AuthGuard.sol";
import "./interfaces/ICod.sol";
import "./interfaces/IShare.sol";
import "./interfaces/ITreasury.sol";

contract Staking is IStaking, AuthGuard {
    /* ========== DATA STRUCTURES ========== */
    struct StakeUser {
        uint256 balance;
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
        uint256 epochTimerStart;
    }

    struct StakingSnapshot {
        uint256 time;
        uint256 rewardReceived;
        uint256 rewardPerShare;
    }

    /* ========== STATE VARIABLES ========== */
    ICod private immutable tomb;
    IShare private immutable share;
    ITreasury private immutable treasury;

    mapping(address => StakeUser) public users;
    StakingSnapshot[] public snapshotHistory;

    uint256 public totalValueLocked;
    uint256 public withdrawLockupEpochs;
    uint256 public rewardLockupEpochs;

    /* ========== EVENTS ========== */
    event Initialized(address indexed executor, uint256 at);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(address indexed user, uint256 reward);

    constructor(
        address _tomb,
        address _share,
        address _treasury,
        address _auth
    ) AuthGuard(_auth) {
        tomb = ICod(_tomb);
        share = IShare(_share);
        treasury = ITreasury(_treasury);

        StakingSnapshot memory genesisSnapshot = StakingSnapshot({time : block.number, rewardReceived : 0, rewardPerShare : 0});
        snapshotHistory.push(genesisSnapshot);

        withdrawLockupEpochs = 6; // Lock for 6 epochs (36h) before release withdraw
        rewardLockupEpochs = 3; // Lock for 3 epochs (18h) before release claimReward
    }

    /* ========== Modifiers =============== */
    modifier updateReward() {
        StakeUser memory seat = users[msg.sender];
        seat.rewardEarned = earned(msg.sender);
        seat.lastSnapshotIndex = latestSnapshotIndex();
        users[msg.sender] = seat;
        _;
    }

    /* ========== GOVERNANCE ========== */
    function setLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external onlyGovernor {
        require(_withdrawLockupEpochs >= _rewardLockupEpochs && _withdrawLockupEpochs <= 56, "_withdrawLockupEpochs: OoR"); // <= 2 week

        withdrawLockupEpochs = _withdrawLockupEpochs;
        rewardLockupEpochs = _rewardLockupEpochs;
    }

    /* ========== VIEW FUNCTIONS ========== */
    function latestSnapshotIndex() public view returns (uint256) {
        return snapshotHistory.length - 1;
    }

    function getLatestSnapshot() internal view returns (StakingSnapshot memory) {
        return snapshotHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address _acc) public view returns (uint256) {
        return users[_acc].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address _acc) internal view returns (StakingSnapshot memory) {
        return snapshotHistory[getLastSnapshotIndexOf(_acc)];
    }

    function canWithdraw(address _acc) external view returns (bool) {
        return users[_acc].epochTimerStart + withdrawLockupEpochs <= treasury.epoch();
    }

    function canClaimReward(address _acc) external view returns (bool) {
        return users[_acc].epochTimerStart + rewardLockupEpochs <= treasury.epoch();
    }

    // =========== Mason getters
    function rewardPerShare() public view returns (uint256) {
        return getLatestSnapshot().rewardPerShare;
    }

    function earned(address _acc) public view returns (uint256) {
        uint256 latestRPS = getLatestSnapshot().rewardPerShare;
        uint256 storedRPS = getLastSnapshotOf(_acc).rewardPerShare;

        return users[_acc].balance * (latestRPS - storedRPS) / 1e18 + users[_acc].rewardEarned;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function stake(uint256 _amount) public updateReward {
        // Checks
        require(_amount > 0, "Masonry: Cannot stake 0");
        // Effects
        users[msg.sender].balance += _amount;
        users[msg.sender].epochTimerStart = treasury.epoch(); // reset timer
        totalValueLocked += _amount;
        // Interactions
        share.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public updateReward {
        // Checks
        require(_amount > 0, "Masonry: Cannot withdraw 0");
        require(users[msg.sender].balance >= _amount, "Masonry: Not enough funds");
        require(users[msg.sender].epochTimerStart + withdrawLockupEpochs <= treasury.epoch(), "Masonry: still lockup");
        // Effects
        users[msg.sender].balance -= _amount;
        totalValueLocked -= _amount;
        // Interactions
        share.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function exit() external {
        withdraw(users[msg.sender].balance);
    }

    function claimReward() public updateReward {
        uint256 reward = users[msg.sender].rewardEarned;
        // Checks
        require(reward > 0, "Masonry: No claimable reward");
        require(users[msg.sender].epochTimerStart + rewardLockupEpochs <= treasury.epoch(), "Masonry: still in reward lockup");
        // Effects
        users[msg.sender].epochTimerStart = treasury.epoch(); // reset timer
        users[msg.sender].rewardEarned = 0;
        // Interactions
        tomb.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function allocateSeigniorage(uint256 _amount) external onlyTreasury {
        // Checks
        require(_amount > 0, "Masonry: Amount = 0");
        require(totalValueLocked > 0, "Masonry: TotalSupply = 0");
        // Effects
        uint256 prevRPS = getLatestSnapshot().rewardPerShare;
        uint256 nextRPS = prevRPS + (_amount * 1e18 / totalValueLocked);
        StakingSnapshot memory newSnapshot = StakingSnapshot({
            time: block.number,
            rewardReceived: _amount,
            rewardPerShare: nextRPS
        });
        snapshotHistory.push(newSnapshot);
        // Interactions
        tomb.transferFrom(msg.sender, address(this), _amount);
        emit RewardAdded(msg.sender, _amount);
    }
}
