// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./types/AuthGuard.sol";
import "./interfaces/ITomb.sol";
import "./interfaces/IShare.sol";
import "./interfaces/ITreasury.sol";

contract Masonry is AuthGuard {
    /* ========== DATA STRUCTURES ========== */
    struct Masonseat {
        uint256 balance;
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
        uint256 epochTimerStart;
    }

    struct MasonrySnapshot {
        uint256 time;
        uint256 rewardReceived;
        uint256 rewardPerShare;
    }

    /* ========== STATE VARIABLES ========== */
    ITomb private immutable tomb;
    IShare private immutable share;
    ITreasury private immutable treasury;

    mapping(address => Masonseat) public masons;
    MasonrySnapshot[] public masonryHistory;

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
        tomb = ITomb(_tomb);
        share = IShare(_share);
        treasury = ITreasury(_treasury);

        MasonrySnapshot memory genesisSnapshot = MasonrySnapshot({time : block.number, rewardReceived : 0, rewardPerShare : 0});
        masonryHistory.push(genesisSnapshot);

        withdrawLockupEpochs = 6; // Lock for 6 epochs (36h) before release withdraw
        rewardLockupEpochs = 3; // Lock for 3 epochs (18h) before release claimReward
    }

    /* ========== Modifiers =============== */
    modifier updateReward() {
        Masonseat memory seat = masons[msg.sender];
        seat.rewardEarned = earned(msg.sender);
        seat.lastSnapshotIndex = latestSnapshotIndex();
        masons[msg.sender] = seat;
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
        return masonryHistory.length - 1;
    }

    function getLatestSnapshot() internal view returns (MasonrySnapshot memory) {
        return masonryHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address mason) public view returns (uint256) {
        return masons[mason].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address mason) internal view returns (MasonrySnapshot memory) {
        return masonryHistory[getLastSnapshotIndexOf(mason)];
    }

    function canWithdraw(address mason) external view returns (bool) {
        return masons[mason].epochTimerStart + withdrawLockupEpochs <= treasury.epoch();
    }

    function canClaimReward(address mason) external view returns (bool) {
        return masons[mason].epochTimerStart + rewardLockupEpochs <= treasury.epoch();
    }

    function epoch() external view returns (uint256) {
        return treasury.epoch();
    }

    function nextEpochPoint() external view returns (uint256) {
        return treasury.nextEpochPoint();
    }

    function getTombPrice() external view returns (uint256) {
        return treasury.getTombPrice();
    }

    // =========== Mason getters
    function rewardPerShare() public view returns (uint256) {
        return getLatestSnapshot().rewardPerShare;
    }

    function earned(address mason) public view returns (uint256) {
        uint256 latestRPS = getLatestSnapshot().rewardPerShare;
        uint256 storedRPS = getLastSnapshotOf(mason).rewardPerShare;

        return masons[mason].balance * (latestRPS - storedRPS) / 1e18 + masons[mason].rewardEarned;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function stake(uint256 amount) public updateReward {
        // Checks
        require(amount > 0, "Masonry: Cannot stake 0");
        // Effects
        masons[msg.sender].balance += amount;
        masons[msg.sender].epochTimerStart = treasury.epoch(); // reset timer
        totalValueLocked += amount;
        // Interactions
        share.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward {
        // Checks
        require(amount > 0, "Masonry: Cannot withdraw 0");
        require(masons[msg.sender].balance >= amount, "Masonry: Not enough funds");
        require(masons[msg.sender].epochTimerStart + withdrawLockupEpochs <= treasury.epoch(), "Masonry: still lockup");
        // Effects
        masons[msg.sender].balance -= amount;
        totalValueLocked -= amount;
        // Interactions
        share.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(masons[msg.sender].balance);
    }

    function claimReward() public updateReward {
        uint256 reward = masons[msg.sender].rewardEarned;
        // Checks
        require(reward > 0, "Masonry: No claimable reward");
        require(masons[msg.sender].epochTimerStart + rewardLockupEpochs <= treasury.epoch(), "Masonry: still in reward lockup");
        // Effects
        masons[msg.sender].epochTimerStart = treasury.epoch(); // reset timer
        masons[msg.sender].rewardEarned = 0;
        // Interactions
        tomb.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function allocateSeigniorage(uint256 amount) external onlyTreasury {
        // Checks
        require(amount > 0, "Masonry: Amount = 0");
        require(totalValueLocked > 0, "Masonry: TotalSupply = 0");
        // Effects
        uint256 prevRPS = getLatestSnapshot().rewardPerShare;
        uint256 nextRPS = prevRPS + (amount * 1e18 / totalValueLocked);
        MasonrySnapshot memory newSnapshot = MasonrySnapshot({
            time: block.number,
            rewardReceived: amount,
            rewardPerShare: nextRPS
        });
        masonryHistory.push(newSnapshot);
        // Interactions
        tomb.transferFrom(msg.sender, address(this), amount);
        emit RewardAdded(msg.sender, amount);
    }
}
