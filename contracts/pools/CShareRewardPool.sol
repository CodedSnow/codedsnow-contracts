// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../types/AuthGuard.sol";
import "../interfaces/IERC20.sol";

// 59500 TOTAL SHARE ALLOCATED (totalAllocPoint)
// 35500 MATIC/COD
// 24000 MATIC/CSHARE

// Note that this pool has no minter key of cSHARE (rewards).
// Instead, the governance will call cSHARE distributeReward method and send reward to this pool at the beginning.
contract CShareRewardPool is AuthGuard {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 token; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. tSHAREs to distribute per block.
        uint256 lastRewardTime; // Last time that tSHAREs distribution occurs.
        uint256 accCSharePerShare; // Accumulated tSHAREs per share, times 1e18. See below.
        bool isStarted; // if lastRewardTime has passed
    }

    IERC20 public cshare;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The time when cSHARE mining starts.
    uint256 public poolStartTime;

    // The time when cSHARE mining ends.
    uint256 public poolEndTime;

    // uint256 public cSharePerSecond = 0.00186122 ether; // 59500 cshare / (370 days * 24h * 60min * 60s)
    uint256 public cSharePerSecond = 0.00169544 ether; // 54200 cshare / (370 days * 24h * 60min * 60s) => rounded down
    uint256 public runningTime = 370 days; // 370 days

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);

    constructor(
        address _cshare,
        uint256 _poolStartTime,
        address _auth
    ) AuthGuard(_auth) {
        // Validate the start time
        require(block.timestamp < _poolStartTime, "Invalid date");

        cshare = IERC20(_cshare);
        poolStartTime = _poolStartTime;
        poolEndTime = poolStartTime + runningTime;
    }

    function checkPoolDuplicate(IERC20 _token) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].token != _token, "CShareRewardPool: existing pool?");
        }
    }

    // Add a new lp to the pool.
    // _allocPoint => x
    // _lpAddr => The LP-ERC20 Token address
    // _withUpdate => Whether to update all pools
    // _lastRewardTime => The last reward time
    function add(uint256 _allocPoint, address _lpAddr, bool _withUpdate, uint256 _lastRewardTime) public onlyGuardian {
        IERC20 _token = IERC20(_lpAddr);

        // Check for duplicates
        checkPoolDuplicate(_token);

        // Check if pools should be updated
        if (_withUpdate) {
            massUpdatePools();
        }

        // Handle reward times
        if (block.timestamp < poolStartTime) {
            // chef is sleeping
            if (_lastRewardTime == 0) {
                _lastRewardTime = poolStartTime;
            } else {
                if (_lastRewardTime < poolStartTime) {
                    _lastRewardTime = poolStartTime;
                }
            }
        } else {
            // chef is cooking
            if (_lastRewardTime == 0 || _lastRewardTime < block.timestamp) {
                _lastRewardTime = block.timestamp;
            }
        }

        // CHeck if started
        bool _isStarted = (_lastRewardTime <= poolStartTime) || (_lastRewardTime <= block.timestamp);
        // Commit (push) the pool
        poolInfo.push(PoolInfo({
            token : _token,
            allocPoint : _allocPoint,
            lastRewardTime : _lastRewardTime,
            accCSharePerShare : 0,
            isStarted : _isStarted
        }));

        if (_isStarted) {
            totalAllocPoint = totalAllocPoint + _allocPoint;
        }
    }

    // Update the given pool's cSHARE allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) public onlyGuardian {
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        }
        pool.allocPoint = _allocPoint;
    }

    // Return accumulate rewards over the given _from to _to block.
    function getGeneratedReward(uint256 _fromTime, uint256 _toTime) public view returns (uint256) {
        // Check if the time from is higher or equal to the to time
        if (_fromTime >= _toTime) return 0;

        // If the time to calculate to is beyond pool end time
        if (_toTime >= poolEndTime) {
            // If even the from time is beyond then 0
            if (_fromTime >= poolEndTime) return 0;
            // If from is before start time
            if (_fromTime <= poolStartTime) {
                // Return the entire period
                return (poolEndTime - poolStartTime) * cSharePerSecond;
            }
            // If the from time is not from before the start time, calculate the difference
            return (poolEndTime - _fromTime) * cSharePerSecond;
        } else {
            // If the to time is before start time then 0
            if (_toTime <= poolStartTime) return 0;

            // If from time is before start time
            if (_fromTime <= poolStartTime) {
                // Return entire period
                return (_toTime - poolStartTime) * cSharePerSecond;
            }

            // If the from time is not the start time then calculate the difference
            return (_toTime - _fromTime) * cSharePerSecond;
        }
    }

    // View function to see pending tSHAREs on frontend.
    function pendingShare(uint256 _pid, address _user) external view returns (uint256) {
        // Define some variables
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCSharePerShare = pool.accCSharePerShare;
        uint256 tokenSupply = pool.token.balanceOf(address(this));

        // Check if we are further than the last reward time and the supply is not naught
        if (block.timestamp > pool.lastRewardTime && tokenSupply != 0) {
            // Get the generated reward given the last reward time + current time
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            // Get the portion of shares that is allocated to this pool times the generated reward
            uint256 _cshareReward = _generatedReward * pool.allocPoint / totalAllocPoint;
            // Get the accCSharePerShare and add it to the reward devided by the total amount
            accCSharePerShare = accCSharePerShare + (_cshareReward * 1e18 / tokenSupply);
        }
        // Fix the final reward amount
        return user.amount * accCSharePerShare / 1e18 - user.rewardDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint + pool.allocPoint;
        }
        if (totalAllocPoint > 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            uint256 _cshareReward = _generatedReward * pool.allocPoint / totalAllocPoint;
            pool.accCSharePerShare = pool.accCSharePerShare + (_cshareReward * 1e18 / tokenSupply);
        }
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens.
    function deposit(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 _pending = user.amount * pool.accCSharePerShare / 1e18 - user.rewardDebt;
            if (_pending > 0) {
                safeCShareTransfer(_sender, _pending);
                emit RewardPaid(_sender, _pending);
            }
        }
        if (_amount > 0) {
            pool.token.transferFrom(_sender, address(this), _amount);
            user.amount = user.amount + _amount;
        }
        user.rewardDebt = user.amount * pool.accCSharePerShare / 1e18;
        emit Deposit(_sender, _pid, _amount);
    }

    // Withdraw LP tokens.
    function withdraw(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 _pending = user.amount * pool.accCSharePerShare / 1e18 - user.rewardDebt;
        if (_pending > 0) {
            safeCShareTransfer(_sender, _pending);
            emit RewardPaid(_sender, _pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.token.transfer(_sender, _amount);
        }
        user.rewardDebt = user.amount * pool.accCSharePerShare / 1e18;
        emit Withdraw(_sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.token.transfer(msg.sender, _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    // Safe cshare transfer function, just in case if rounding error causes pool to not have enough tSHAREs.
    function safeCShareTransfer(address _to, uint256 _amount) internal {
        uint256 _tshareBal = cshare.balanceOf(address(this));
        if (_tshareBal > 0) {
            if (_amount > _tshareBal) {
                cshare.transfer(_to, _tshareBal);
            } else {
                cshare.transfer(_to, _amount);
            }
        }
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 amount, address to) external onlyGovernor {
        if (block.timestamp < poolEndTime + 90 days) {
            // do not allow to drain core token (cSHARE or lps) if less than 90 days after pool ends
            require(_token != cshare, "cshare");
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                PoolInfo storage pool = poolInfo[pid];
                require(_token != pool.token, "pool.token");
            }
        }
        _token.transfer(to, amount);
    }
}