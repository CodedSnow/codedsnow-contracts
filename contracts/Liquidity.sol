// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3Factory.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./libraries/PoolAddress.sol";
import "./types/AuthGuard.sol";
import "./libraries/CheckValidation.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityAmounts.sol";

contract Liquidity is AuthGuard, IUniswapV3MintCallback {
    /* ========== STATE VARIABLES ========== */
    address private constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    // https://info.uniswap.org/#/polygon/tokens/0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270
    address private constant WRAPPED_MATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    // Other contract addresses
    address private immutable cod;
    address private immutable cshare;
    address private immutable treasury;

    // Pool addresses
    address public codPool;
    address public sharePool;

    // Balance variables
    uint256 public codSellBalance;
    uint256 public shareSellBalance;
    uint256 public codMatic;
    uint256 public shareMatic;

    uint256 public immutable codDiscountPercentage;
    uint256 public immutable shareDiscountPercentage;

    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address token;
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        uint24 fee;
        address recipient;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /* ========== CONSTRUCTOR ========== */
    constructor(
        address _cod,
        address _cshare,
        address _treasury,
        address _auth
    ) AuthGuard(_auth) {
        cod = _cod;
        cshare = _cshare;
        treasury = _treasury;

        codSellBalance = 15000 * 10e18 * 625 / 1000; // 62.5% of 15000 cod
        shareSellBalance = 15 * 10e18 * 572 / 1000; // 57.2% of 15 share

        codDiscountPercentage = 600;
        shareDiscountPercentage = 750;
    }

    // Buy Cod with MATIC, _amount in COD
    function buyCod(uint256 _amount) external {
        uint256 maticAmount = _amount * codDiscountPercentage / 1000;
        // Check if user has enough matic
        require(IERC20(WRAPPED_MATIC).balanceOf(msg.sender) >= maticAmount, "Not enough funds");
        
        // Check if presale has enough cod to sell
        require(_amount <= codSellBalance, "Presale-Cod depleted");

        // Receive the MATIC
        IERC20(WRAPPED_MATIC).transferFrom(msg.sender, address(this), _amount);
        codMatic += _amount;

        if (codPool == address(0)) {
            codPool = IUniswapV3Factory(UNISWAP_FACTORY).createPool(WRAPPED_MATIC, cod, 3000);
            IUniswapV3Pool(codPool).initialize(1);
        } else {
            // TODO: Add liquidity of previous if
            addLiquidity(AddLiquidityParams({
                token0: WRAPPED_MATIC,
                token1: cod,
                fee: 3000,
                recipient: treasury,
                tickLower: -250000,
                tickUpper: 250000,
                amount0Desired: maticAmount,
                amount1Desired: maticAmount,
                amount0Min: maticAmount * 75 / 100,
                amount1Min: maticAmount * 75 / 100
            }));
        }

        // Deduct the balance
        codSellBalance -= _amount;
        // Send the tokens
        IERC20(cod).transfer(msg.sender, _amount);
    }

    // Buy Share with MATIC, _amount in SHARE
    function buyShare(uint256 _amount) external {
        uint256 maticAmount = _amount * shareDiscountPercentage; // Because percentage is in 1000 we do not have to add any multiplier
        // Check if user has enough matic
        require(IERC20(WRAPPED_MATIC).balanceOf(msg.sender) >= maticAmount, "Not enough funds");
        
        // Check if presale has enough share to sell
        require(_amount <= codSellBalance, "Presale-Share depleted");

        // Receive the MATIC
        IERC20(WRAPPED_MATIC).transferFrom(msg.sender, address(this), _amount);
        shareMatic += _amount;

        uint256 shareLiqAmount = maticAmount / 1000;

        if (sharePool == address(0)) {
            sharePool = IUniswapV3Factory(UNISWAP_FACTORY).createPool(WRAPPED_MATIC, cshare, 3000);
            IUniswapV3Pool(codPool).initialize(uint160(sqrt(1 / 1000))); // TODO: Switch this around?
        } else {
            // TODO: Add liquidity of previous if
            addLiquidity(AddLiquidityParams({
                token0: WRAPPED_MATIC,
                token1: cshare,
                fee: 3000,
                recipient: treasury,
                tickLower: -250000,
                tickUpper: 250000,
                amount0Desired: maticAmount,
                amount1Desired: shareLiqAmount,
                amount0Min: maticAmount * 75 / 100,
                amount1Min: shareLiqAmount * 75 / 100
            }));
        }


        // Deduct the balance
        shareSellBalance -= _amount;
        // Send the tokens
        IERC20(cshare).transfer(msg.sender, _amount);
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

        if (decoded.token == cod) {
            // IUniswapV3Pool myPool = IUniswapV3Pool(PoolAddress.computeAddress(UNISWAP_FACTORY, PoolAddress.getPoolKey(WRAPPED_MATIC, cod, 3000)));
            require(codPool == msg.sender, "Malicious callback");

            // Transfer COD
            IERC20(cod).transfer(msg.sender, amount1Owed);
        } else if (decoded.token == cshare) {
            // IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(UNISWAP_FACTORY, PoolAddress.getPoolKey(WRAPPED_MATIC, cshare, 3000)));
            require(sharePool == msg.sender, "Malicious callback");

            // Transfer CSHARE
            IERC20(cshare).transfer(msg.sender, amount1Owed);
        }

        // Transfer MATIC
        IERC20(WRAPPED_MATIC).transfer(msg.sender, amount0Owed);
    }

    /* ========== PRIVATE FUNCTIONS ========== */
    function sqrt(uint x) private returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    // The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback in which they must pay any token0 or token1 owed for the liquidity
    function addLiquidity(AddLiquidityParams memory params) private returns (uint128 liquidity, uint256 amount0, uint256 amount1, IUniswapV3Pool pool) {
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee});
        pool = IUniswapV3Pool(PoolAddress.computeAddress(UNISWAP_FACTORY, poolKey));

        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                params.amount0Desired,
                params.amount1Desired
            );
        }

        (amount0, amount1) = pool.mint(
            params.recipient,
            params.tickLower,
            params.tickUpper,
            liquidity,
            abi.encode(MintCallbackData({poolKey: poolKey, token: params.token1}))
        );

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "Slippage check");
    }
}