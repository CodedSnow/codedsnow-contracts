// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./interfaces/IUniswapV3Pool.sol";
import "./types/AuthGuard.sol";
import "./libraries/OracleLibrary.sol";
import "./libraries/SafeCast.sol";
import "./interfaces/IMasonry.sol";

import "./interfaces/ITomb.sol";
import "./interfaces/IBond.sol";
import "./interfaces/IShare.sol";
import "./interfaces/ITreasury.sol";

contract Treasury is ITreasury, AuthGuard {
    /* ========= CONSTANT VARIABLES ======== */
    uint256 public constant PERIOD = 6 hours;

    /* ========== STATE VARIABLES ========== */
    // epoch
    uint256 public startTime;
    uint256 public epoch = 0;
    uint256 public epochSupplyContractionLeft = 0;

    // core components
    address public tomb;
    address public tbond;
    address public tshare;
    
    address private _nativePool;
    uint256 private _twapPeriod;

    address public masonry;

    // price
    uint256 public tombPriceOne;
    uint256 public tombPriceCeiling;

    uint256 public seigniorageSaved;

    uint256[] public supplyTiers;
    uint256[] public maxExpansionTiers;

    uint256 public maxSupplyExpansionPercent;
    uint256 public bondDepletionFloorPercent;
    uint256 public seigniorageExpansionFloorPercent;
    uint256 public maxSupplyContractionPercent;
    uint256 public maxDebtRatioPercent;

    // 28 first epochs (1 week) with 4.5% expansion regardless of TOMB price
    uint256 public bootstrapEpochs;
    uint256 public bootstrapSupplyExpansionPercent;

    /* =================== Added variables =================== */
    uint256 public previousEpochTombPrice;
    uint256 public maxDiscountRate; // when purchasing bond
    uint256 public maxPremiumRate; // when redeeming bond
    uint256 public discountPercent;
    uint256 public premiumThreshold;
    uint256 public premiumPercent;
    uint256 public mintingFactorForPayingDebt; // print extra TOMB during debt phase

    address public daoFund;
    uint256 public daoFundSharedPercent;

    address public devFund;
    uint256 public devFundSharedPercent;

    uint256 public _tombPrice;

    /* =================== Events =================== */
    event BurnedBonds(address indexed from, uint256 bondAmount);
    event RedeemedBonds(address indexed from, uint256 tombAmount, uint256 bondAmount);
    event BoughtBonds(address indexed from, uint256 tombAmount, uint256 bondAmount);
    event TreasuryFunded(uint256 timestamp, uint256 seigniorage);
    event MasonryFunded(uint256 timestamp, uint256 seigniorage);
    event DaoFundFunded(uint256 timestamp, uint256 seigniorage);
    event DevFundFunded(uint256 timestamp, uint256 seigniorage);

    constructor(
        address _tomb,
        address _tbond,
        address _tshare,
        uint256 _startTime,
        address _auth
    ) AuthGuard(_auth) {
        tomb = _tomb;
        tbond = _tbond;
        tshare = _tshare;
        startTime = _startTime;

        _twapPeriod = 1800; // Every 30 minutes

        tombPriceOne = 10**18;
        tombPriceCeiling = tombPriceOne * 101 / 100;

        // Dynamic max expansion percent
        supplyTiers = [0 ether, 500000 ether, 1000000 ether, 1500000 ether, 2000000 ether, 5000000 ether, 10000000 ether, 20000000 ether, 50000000 ether];
        maxExpansionTiers = [450, 400, 350, 300, 250, 200, 150, 125, 100];

        maxSupplyExpansionPercent = 400; // Upto 4.0% supply for expansion

        bondDepletionFloorPercent = 10000; // 100% of Bond supply for depletion floor
        seigniorageExpansionFloorPercent = 3500; // At least 35% of expansion reserved for masonry
        maxSupplyContractionPercent = 300; // Upto 3.0% supply for contraction (to burn TOMB and mint tBOND)
        maxDebtRatioPercent = 3500; // Upto 35% supply of tBOND to purchase

        premiumThreshold = 110;
        premiumPercent = 7000;

        // First 28 epochs with 4.5% expansion
        bootstrapEpochs = 28;
        bootstrapSupplyExpansionPercent = 450;

        // set seigniorageSaved to it's balance
        seigniorageSaved = ITomb(tomb).balanceOf(address(this));
    }

    function setNativePool(address _pool) external onlyGovernor {
        _nativePool = _pool;
    }
    
    function setMasonry(address _masonry) external onlyGovernor {
        masonry = _masonry;
    }

    /* =================== Modifier =================== */
    modifier checkCondition {
        require(block.timestamp >= startTime, "Treasury: not started yet");
        _;
    }

    modifier checkEpoch {
        require(block.timestamp >= nextEpochPoint(), "Treasury: not opened yet");
        _;
        epoch = epoch + 1;
        epochSupplyContractionLeft = (getTombPrice() > tombPriceCeiling) ? 0 : getTombCirculatingSupply() * maxSupplyContractionPercent / 10000;
    }

    /* ========== VIEW FUNCTIONS ========== */
    // epoch
    function nextEpochPoint() public view returns (uint256) {
        return startTime + (epoch * PERIOD);
    }

    // oracle
    function getTombPrice() public view returns (uint256 tombPrice) {
        return _tombPrice;
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

    // budget
    function getReserve() public view returns (uint256) {
        return seigniorageSaved;
    }

    function getBurnableTombLeft() public view returns (uint256 _burnableTombLeft) {
        uint256 _price = getTombPrice();
        if (_price <= tombPriceOne) {
            uint256 _tombSupply = getTombCirculatingSupply();
            uint256 _bondMaxSupply = _tombSupply * maxDebtRatioPercent / 10000;
            uint256 _bondSupply = IBond(tbond).totalSupply();
            if (_bondMaxSupply > _bondSupply) {
                uint256 _maxMintableBond = _bondMaxSupply - _bondSupply;
                uint256 _maxBurnableTomb = _maxMintableBond * _price / 1e18;
                _burnableTombLeft = min(epochSupplyContractionLeft, _maxBurnableTomb);
            }
        }
    }

    function getRedeemableBonds() public view returns (uint256 _redeemableBonds) {
        uint256 _price = getTombPrice();
        if (_price > tombPriceCeiling) {
            uint256 _totalTomb = ITomb(tomb).balanceOf(address(this));
            uint256 _rate = getBondPremiumRate();
            if (_rate > 0) {
                _redeemableBonds = _totalTomb * 1e18 / _rate;
            }
        }
    }

    function getBondDiscountRate() public view returns (uint256 _rate) {
        uint256 _price = getTombPrice();
        if (_price <= tombPriceOne) {
            if (discountPercent == 0) {
                // no discount
                _rate = tombPriceOne;
            } else {
                uint256 _bondAmount = tombPriceOne * 1e18 / _price; // to burn 1 TOMB
                uint256 _discountAmount = (_bondAmount - tombPriceOne) * discountPercent / 10000;
                _rate = tombPriceOne + _discountAmount;
                if (maxDiscountRate > 0 && _rate > maxDiscountRate) {
                    _rate = maxDiscountRate;
                }
            }
        }
    }

    function getBondPremiumRate() public view returns (uint256 _rate) {
        uint256 _price = getTombPrice();
        if (_price > tombPriceCeiling) {
            uint256 _tombPricePremiumThreshold = tombPriceOne * premiumThreshold / 100;
            if (_price >= _tombPricePremiumThreshold) {
                //Price > 1.10
                uint256 _premiumAmount = (_price - tombPriceOne) * premiumPercent / 10000;
                _rate = tombPriceOne + _premiumAmount;
                if (maxPremiumRate > 0 && _rate > maxPremiumRate) {
                    _rate = maxPremiumRate;
                }
            } else {
                // no premium bonus
                _rate = tombPriceOne;
            }
        }
    }

    /* ========== GOVERNANCE ========== */
    function setTwapPeriod(uint256 _period) external onlyGuardian {
        _twapPeriod = _period;
    }

    function setTombPriceCeiling(uint256 _tombPriceCeiling) external onlyGovernor {
        require(_tombPriceCeiling >= tombPriceOne && _tombPriceCeiling <= tombPriceOne * 120 / 100, "OoR"); // [$1.0, $1.2]
        tombPriceCeiling = _tombPriceCeiling;
    }

    function setMaxSupplyExpansionPercents(uint256 _maxSupplyExpansionPercent) external onlyGovernor {
        require(_maxSupplyExpansionPercent >= 10 && _maxSupplyExpansionPercent <= 1000, "_maxSupplyExpansionPercent: OoR"); // [0.1%, 10%]
        maxSupplyExpansionPercent = _maxSupplyExpansionPercent;
    }

    function setSupplyTiersEntry(uint8 _index, uint256 _value) external onlyGovernor returns (bool) {
        require(_index >= 0, "Index >= 0 not satisfied");
        require(_index < 9, "Index < TierCount not satisfied");
        if (_index > 0) {
            require(_value > supplyTiers[_index - 1], "Invalid value");
        }
        if (_index < 8) {
            require(_value < supplyTiers[_index + 1], "Invalid value");
        }
        supplyTiers[_index] = _value;
        return true;
    }

    function setMaxExpansionTiersEntry(uint8 _index, uint256 _value) external onlyGovernor returns (bool) {
        require(_index >= 0, "Index >= 0 not satisfied");
        require(_index < 9, "Index < TierCount not satisfied");
        require(_value >= 10 && _value <= 1000, "_value: OoR"); // [0.1%, 10%]
        maxExpansionTiers[_index] = _value;
        return true;
    }

    function setBondDepletionFloorPercent(uint256 _bondDepletionFloorPercent) external onlyGovernor {
        require(_bondDepletionFloorPercent >= 500 && _bondDepletionFloorPercent <= 10000, "OoR"); // [5%, 100%]
        bondDepletionFloorPercent = _bondDepletionFloorPercent;
    }

    function setMaxSupplyContractionPercent(uint256 _maxSupplyContractionPercent) external onlyGovernor {
        require(_maxSupplyContractionPercent >= 100 && _maxSupplyContractionPercent <= 1500, "OoR"); // [0.1%, 15%]
        maxSupplyContractionPercent = _maxSupplyContractionPercent;
    }

    function setMaxDebtRatioPercent(uint256 _maxDebtRatioPercent) external onlyGovernor {
        require(_maxDebtRatioPercent >= 1000 && _maxDebtRatioPercent <= 10000, "OoR"); // [10%, 100%]
        maxDebtRatioPercent = _maxDebtRatioPercent;
    }

    function setBootstrap(uint256 _bootstrapEpochs, uint256 _bootstrapSupplyExpansionPercent) external onlyGovernor {
        require(_bootstrapEpochs <= 120, "_bootstrapEpochs: OoR"); // <= 1 month
        require(_bootstrapSupplyExpansionPercent >= 100 && _bootstrapSupplyExpansionPercent <= 1000, "OoR"); // [1%, 10%]
        bootstrapEpochs = _bootstrapEpochs;
        bootstrapSupplyExpansionPercent = _bootstrapSupplyExpansionPercent;
    }

    function setExtraFunds(
        address _daoFund,
        uint256 _daoFundSharedPercent,
        address _devFund,
        uint256 _devFundSharedPercent
    ) external onlyGovernor {
        require(_daoFund != address(0), "zero");
        require(_daoFundSharedPercent <= 3000, "OoR"); // <= 30%
        require(_devFund != address(0), "zero");
        require(_devFundSharedPercent <= 1000, "OoR"); // <= 10%
        daoFund = _daoFund;
        daoFundSharedPercent = _daoFundSharedPercent;
        devFund = _devFund;
        devFundSharedPercent = _devFundSharedPercent;
    }

    function setMaxDiscountRate(uint256 _maxDiscountRate) external onlyGovernor {
        maxDiscountRate = _maxDiscountRate;
    }

    function setMaxPremiumRate(uint256 _maxPremiumRate) external onlyGovernor {
        maxPremiumRate = _maxPremiumRate;
    }

    function setDiscountPercent(uint256 _discountPercent) external onlyGovernor {
        require(_discountPercent <= 20000, "_discountPercent is over 200%");
        discountPercent = _discountPercent;
    }

    function setPremiumThreshold(uint256 _premiumThreshold) external onlyGovernor {
        require(_premiumThreshold >= tombPriceCeiling, "Threshold < Ceiling");
        require(_premiumThreshold <= 150, "Threshold > 150 (1.5)");
        premiumThreshold = _premiumThreshold;
    }

    function setPremiumPercent(uint256 _premiumPercent) external onlyGovernor {
        require(_premiumPercent <= 20000, "_premiumPercent > 200%");
        premiumPercent = _premiumPercent;
    }

    function setMintingFactorForPayingDebt(uint256 _mintingFactorForPayingDebt) external onlyGovernor {
        require(_mintingFactorForPayingDebt >= 10000 && _mintingFactorForPayingDebt <= 20000, " OoR"); // [100%, 200%]
        mintingFactorForPayingDebt = _mintingFactorForPayingDebt;
    }

    /* ========== MUTABLE FUNCTIONS ========== */
    function _updateTombPrice() internal {
        _tombPrice = _fetchAmountFromSinglePool(tomb, 1, 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, _nativePool);
    }

    function getTombCirculatingSupply() public view returns (uint256) {
        uint256 totalSupply = ITomb(tomb).totalSupply();
        uint256 balanceExcluded = ITomb(tomb).balanceOf(_nativePool);

        return totalSupply - balanceExcluded;
    }

    function buyBonds(uint256 _tombAmount, uint256 targetPrice) external checkCondition {
        require(_tombAmount > 0, "Treasury: Invalid amount");

        uint256 tombPrice = getTombPrice();
        require(tombPrice == targetPrice, "Treasury: TOMB price moved");
        require(tombPrice < tombPriceOne, "Treasury: Cannot buy");
        require(_tombAmount <= epochSupplyContractionLeft, "Treasury: Not enough bonds left");

        uint256 _rate = getBondDiscountRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _bondAmount = _tombAmount * _rate / 1e18;
        uint256 tombSupply = getTombCirculatingSupply();
        uint256 newBondSupply = IBond(tbond).totalSupply() + _bondAmount;
        require(newBondSupply <= tombSupply * maxDebtRatioPercent / 10000, "over max debt ratio");

        ITomb(tomb).burn(msg.sender, _tombAmount);
        IBond(tbond).mint(msg.sender, _bondAmount);

        epochSupplyContractionLeft = epochSupplyContractionLeft - _tombAmount;
        _updateTombPrice();

        emit BoughtBonds(msg.sender, _tombAmount, _bondAmount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function redeemBonds(uint256 _bondAmount, uint256 targetPrice) external checkCondition {
        require(_bondAmount > 0, "Treasury: Invalid amount");

        uint256 tombPrice = getTombPrice();
        require(tombPrice == targetPrice, "Treasury: TOMB price moved");
        require(tombPrice > tombPriceCeiling, "Treasury: Cannot redeem");

        uint256 _rate = getBondPremiumRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _tombAmount = _bondAmount * _rate / 1e18;
        require(ITomb(tomb).balanceOf(address(this)) >= _tombAmount, "Treasury: Not enough funds");

        seigniorageSaved = seigniorageSaved - (min(seigniorageSaved, _tombAmount));

        IBond(tbond).burn(msg.sender, _bondAmount);
        ITomb(tomb).transfer(msg.sender, _tombAmount);

        _updateTombPrice();

        emit RedeemedBonds(msg.sender, _tombAmount, _bondAmount);
    }

    function _sendToMasonry(uint256 _amount) internal {
        ITomb(tomb).burn(address(this), _amount);

        uint256 _daoFundSharedAmount = 0;
        if (daoFundSharedPercent > 0) {
            _daoFundSharedAmount = _amount * daoFundSharedPercent / 10000;
        }

        uint256 _devFundSharedAmount = 0;
        if (devFundSharedPercent > 0) {
            _devFundSharedAmount = _amount * devFundSharedPercent / 10000;
        }

        _amount = _amount - _daoFundSharedAmount - _devFundSharedAmount;

        ITomb(tomb).transfer(daoFund, _daoFundSharedAmount);
        emit DaoFundFunded(block.timestamp, _daoFundSharedAmount);
        ITomb(tomb).transfer(devFund, _devFundSharedAmount);
        emit DevFundFunded(block.timestamp, _devFundSharedAmount);

        ITomb(tomb).approve(masonry, 0);
        ITomb(tomb).approve(masonry, _amount);
        IMasonry(masonry).allocateSeigniorage(_amount);
        emit MasonryFunded(block.timestamp, _amount);
    }

    function _calculateMaxSupplyExpansionPercent(uint256 _tombSupply) internal returns (uint256) {
        for (uint8 tierId = 8; tierId >= 0; --tierId) {
            if (_tombSupply >= supplyTiers[tierId]) {
                maxSupplyExpansionPercent = maxExpansionTiers[tierId];
                break;
            }
        }
        return maxSupplyExpansionPercent;
    }

    function allocateSeigniorage() external checkCondition checkEpoch {
        _updateTombPrice();
        previousEpochTombPrice = getTombPrice();
        uint256 tombSupply = getTombCirculatingSupply() - seigniorageSaved;
        if (epoch < bootstrapEpochs) {
            // 28 first epochs with 4.5% expansion
            _sendToMasonry(tombSupply * bootstrapSupplyExpansionPercent / 10000);
        } else {
            if (previousEpochTombPrice > tombPriceCeiling) {
                // Expansion ($TOMB Price > 1 $FTM): there is some seigniorage to be allocated
                uint256 bondSupply = IBond(tbond).totalSupply();
                uint256 _percentage = previousEpochTombPrice - tombPriceOne;
                uint256 _savedForBond;
                uint256 _savedForMasonry;
                uint256 _mse = _calculateMaxSupplyExpansionPercent(tombSupply) * 1e14;
                if (_percentage > _mse) {
                    _percentage = _mse;
                }
                if (seigniorageSaved >= bondSupply * bondDepletionFloorPercent / 10000) {
                    // saved enough to pay debt, mint as usual rate
                    _savedForMasonry = tombSupply * _percentage / 1e18;
                } else {
                    // have not saved enough to pay debt, mint more
                    uint256 _seigniorage = tombSupply * _percentage / 1e18;
                    _savedForMasonry = _seigniorage * seigniorageExpansionFloorPercent / 10000;
                    _savedForBond = _seigniorage - _savedForMasonry;
                    if (mintingFactorForPayingDebt > 0) {
                        _savedForBond = _savedForBond * mintingFactorForPayingDebt / 10000;
                    }
                }
                if (_savedForMasonry > 0) {
                    _sendToMasonry(_savedForMasonry);
                }
                if (_savedForBond > 0) {
                    seigniorageSaved = seigniorageSaved + _savedForBond;
                    ITomb(tomb).mint(address(this), _savedForBond);
                    emit TreasuryFunded(block.timestamp, _savedForBond);
                }
            }
        }
    }
}
