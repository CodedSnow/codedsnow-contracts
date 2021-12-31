// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ITreasury.sol";
import "./interfaces/ICOD.sol";
import "./interfaces/IbCOD.sol";
import "./types/AuthGuard.sol";

import "./interfaces/IUniswapV3Pool.sol";
import "./libraries/OracleLibrary.sol";
import "./libraries/SafeCast.sol";

contract Treasury is ITreasury, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    ICOD public immutable cod;
    IbCOD public immutable bCod;
    address public immutable native; // Address of native token for Uniswap

    address private _nativePool;
    uint256 private _epochTime; // Time between epochs (e.g. 8 hours) (in seconds)
    uint256 private _lastEpoch; // Unix epoch
    uint256 private _totalEpochs; // Total amount of epochs
    uint256 private _twapPeriod;

    uint256 public lastPrice;
    uint256 public targetPrice;
    uint256 public rewardCeiling;
    uint256 public rewardRatio;
    uint256 public maxDebtRatio;

    /* ========== CONSTRUCTOR + SETUP ========== */
    constructor(
        address _cod,
        address _bCod,
        address _native,
        uint256 _currentTime,
        address _authority
    ) AuthGuard(IAuthority(_authority)) {
        cod = ICOD(_cod);
        bCod = IbCOD(_bCod);
        native = _native;

        _epochTime = 18000; // Every 5 hours
        _lastEpoch = _currentTime;
        _twapPeriod = 1800; // Every 30 minutes

        targetPrice = 10**18; // Target price in MATIC
        rewardCeiling = (10**18 * 11) / 10; // In matic (1.1 MATIC)
        rewardRatio = 1000; // 10% in rewards, in COD
        maxDebtRatio = 3500; // Upto 35% supply of bCOD to purchase
    }

    function setNativePool(address _pool) external onlyGovernor {
        _nativePool = _pool;
    }

    /* ========== MODIFIERS ========== */
    modifier checkEpoch() {
        // How many epochs did we miss?
        uint256 missed = (block.timestamp - _lastEpoch) / _epochTime;
        if (missed > 0) {
            _lastEpoch = block.timestamp;
            _totalEpochs + missed;

            lastPrice = assetToNative(address(cod), 10**9);
        }
        _;
    }

    /* ========== GUARDIAN ONLY ========== */
    function setEpochInterval(uint256 _interval) external onlyGuardian {
        _epochTime = _interval;
    }

    function setTargetPrice(uint256 _price) external onlyGuardian {
        targetPrice = _price;
    }

    function setRewardCeiling(uint256 _ceiling) external onlyGuardian {
        rewardCeiling = _ceiling;
    }

    function setRewardRatio(uint256 _ratio) external onlyGuardian {
        rewardRatio = _ratio;
    }

    function setMaxDebtRatio(uint256 _ratio) external onlyGuardian {
        maxDebtRatio = _ratio;
    }

    function setTwapPeriod(uint256 _period) external onlyGuardian {
        _twapPeriod = _period;
    }

    /* ========== PUBLIC FUNCTIONS ========== */
    function canBuyBond() public view returns (bool) {
        return lastPrice < targetPrice;
    }

    function canSellBond() public view returns (bool) {
        // Check if price of bond is higher than > 1.0
        return lastPrice > targetPrice; // 1 * 10**18
    }

    // Obtain the bonus amount in cod
    function calcBonus() public view returns (uint256 bonusCod_) {
        // 1.1 * 10**18
        if (lastPrice >= rewardCeiling) {
            bonusCod_ = lastPrice * rewardRatio / 10000;
        } else {
            bonusCod_ = 0;
        }
    }

    function assetToNative(address _tokenIn, uint256 _amountIn) public view returns (uint256 nativeAmount) {
        nativeAmount = _fetchAmountFromSinglePool(_tokenIn, _amountIn, native, _nativePool);
    }


    /* ========== EXTERNAL FUNCTIONS ========== */
    // Deflate
    function buyBond(uint256 _amount) external checkEpoch {
        require(canBuyBond(), "Cannot buy bond");

        // Circulating COD supply
        uint256 cCodSupply = cod.totalSupply() - cod.balanceOf(address(this));
        // New supply of bCod
        uint256 newSupply = bCod.totalSupply() + _amount;

        uint256 maxDebt = (cCodSupply * maxDebtRatio) / 10000;
        require(newSupply <= maxDebt, "Exceeded max debt ratio");

        // Checks
        require(cod.balanceOf(msg.sender) >= _amount, "Not enough funds");
        // Effects
        cod.burn(msg.sender, _amount);
        bCod.mint(msg.sender, _amount);
        // Interactions
        // TODO: Call event
    }

    // Inflate
    function sellBond(uint256 _amount) external checkEpoch {
        require(canBuyBond(), "Cannot sell bond");

        // Checks
        require(bCod.balanceOf(msg.sender) >= _amount, "Not enough funds");
        // Effects
        bCod.burn(msg.sender, _amount);
        cod.mint(msg.sender, _amount + calcBonus());
        // Interactions
        // TODO: Call event
    }

    function lastEpoch() external view returns (uint256) {
        return _lastEpoch;
    }

    function nextEpoch() external view returns (uint256) {
        return _lastEpoch + _epochTime;
    }

    function totalEpochs() external view returns (uint256) {
        return _totalEpochs;
    }

    function getEpochPrice() external view returns (uint256 codPrice_) {
        codPrice_ = lastPrice;
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    function _fetchAmountFromSinglePool(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _pool
    ) internal view returns (uint256 amountOut) {
        // Leave ticks as int256s to avoid solidity casting
        (int24 spotTick,) = OracleLibrary.getBlockStartingTickAndLiquidity(_pool);
        (int24 twapTick,) = OracleLibrary.consult(_pool, SafeCast.toUint32(_twapPeriod));

        // Return min amount between spot price and twap
        // Ticks are based on the ratio between token0:token1 so if the input token is token1 then
        // we need to treat the tick as an inverse
        int256 minTick;
        if (_tokenIn < _tokenOut) {
            minTick = spotTick < twapTick ? spotTick : twapTick;
        } else {
            minTick = spotTick > twapTick ? spotTick : twapTick;
        }

        return
            OracleLibrary.getQuoteAtTick(
                int24(minTick), // can assume safe being result from consult()
                SafeCast.toUint128(_amountIn),
                _tokenIn,
                _tokenOut
            );
    }
}
