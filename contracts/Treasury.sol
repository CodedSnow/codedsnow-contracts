// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

// Interfaces
import "./interfaces/ITreasury.sol";
import "./interfaces/ICod.sol";
import "./interfaces/ICBond.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IEpoch.sol";
// Types
import "./types/AuthGuard.sol";
// Libraries
import "./libraries/OracleLibrary.sol";
import "./libraries/SafeCast.sol";

contract Treasury is ITreasury, AuthGuard {
    /* ========== STATE VARIABLES ========== */
    address private immutable cod;
    address private immutable cbond;
    address private immutable native; // Address of native token for Uniswap
    address private immutable epoch;

    address private _nativePool;
    uint256 private _twapPeriod;

    uint256 public lastPrice;
    uint256 public targetPrice;
    uint256 public rewardCeiling;
    uint256 public rewardRatio;
    uint256 public maxDebtRatio;

    /* ========== CONSTRUCTOR + SETUP ========== */
    constructor(
        // Tokens
        address _cod,
        address _cbond,
        // Misc
        address _epoch,
        address _native,
        // Auth
        address _auth
    ) AuthGuard(_auth) {
        cod = _cod;
        cbond = _cbond;
        native = _native;
        epoch = _epoch;

        _twapPeriod = 1800; // Every 30 minutes

        targetPrice = 10**18; // Target price in MATIC
        rewardCeiling = (10**18 * 11) / 10; // In matic (1.1 MATIC)
        rewardRatio = 1000; // 10% in rewards, in COD
        maxDebtRatio = 3500; // Upto 35% supply of bCOD to purchase
    }

    function setNativePool(address _pool) external onlyGovernor {
        _nativePool = _pool;
    }

    /* ========== GUARDIAN ONLY ========== */
    function setTwapPeriod(uint256 _period) external onlyGuardian {
        _twapPeriod = _period;
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

    /* ========== PUBLIC FUNCTIONS ========== */
    function updateEpoch() public {
        if (IEpoch(epoch).missedEpochs(block.timestamp) > 0) {
            // Update the price
            lastPrice = assetToNative(cod, 10**9);
            // Send rewards to the staking contract
            // ...

            // Update the epoch
            IEpoch(epoch).updateEpoch();
        }
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

    /* ========== EXTERNAL FUNCTIONS ========== */
    // Deflate
    function buyBond(uint256 _amount) external {
        updateEpoch();
        require(lastPrice < targetPrice, "Cannot buy bond");

        // Define contracts (interfaces)

        // Circulating COD supply
        uint256 cCodSupply = ICod(cod).totalSupply() - ICod(cod).balanceOf(address(this));
        // New supply of CBOND
        uint256 newSupply = ICBond(cbond).totalSupply() + _amount;

        uint256 maxDebt = (cCodSupply * maxDebtRatio) / 10000;
        require(newSupply <= maxDebt, "Exceeded max debt ratio");

        // Checks
        require(ICod(cod).balanceOf(msg.sender) >= _amount, "Not enough funds");
        // Effects
        ICod(cod).burn(msg.sender, _amount);
        ICBond(cbond).mint(msg.sender, _amount);
        // Interactions
        emit BoughtBond(msg.sender, _amount);
    }

    // Inflate
    function sellBond(uint256 _amount) external {
        updateEpoch();
        require(lastPrice > targetPrice, "Cannot sell bond");

        // Checks
        require(ICBond(cbond).balanceOf(msg.sender) >= _amount, "Not enough funds");
        // Effects
        ICBond(cbond).burn(msg.sender, _amount);
        ICod(cod).mint(msg.sender, _amount + calcBonus());
        // Interactions
        emit SoldBond(msg.sender, _amount);
    }

    /* ========== PRIVATE FUNCTIONS ========== */
    function assetToNative(address _tokenIn, uint256 _amountIn) private view returns (uint256) {
        return _fetchAmountFromSinglePool(_tokenIn, _amountIn, native, _nativePool);
    }

    function _fetchAmountFromSinglePool(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _pool
    ) private view returns (uint256) {
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
