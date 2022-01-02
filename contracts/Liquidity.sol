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

    address private immutable cod;
    address private immutable cshare;
    address private immutable treasury;

    address public codPool;
    address public sharePool;

    bool public isOpen;
    uint256 public codMatic;
    uint256 public shareMatic;

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

        isOpen = true;
    }

    function setOpen(bool _open) external onlyGovernor {
        isOpen = _open;
    }

    // Buy Cod with MATIC
    function buyCod(uint256 _amount) external {
        require(isOpen, "Closed");
        require(IERC20(WRAPPED_MATIC).balanceOf(msg.sender) >= _amount, "Not enough funds");

        uint256 codAmount = _amount * 140 / 100; // 60%
        require(codAmount <= IERC20(cod).balanceOf(address(this)), "Presale-Cod depleted");

        // Receive the MATIC
        IERC20(WRAPPED_MATIC).transferFrom(msg.sender, address(this), _amount);
        codMatic += _amount;

        // TODO: Add liquidity
        // ...

        // Transfer the tokens
        IERC20(cod).transfer(msg.sender, codAmount);
    }

    // Buy CShare with MATIC
    function buyCShare(uint256 _amount) external {
        require(isOpen, "Closed");
        require(IERC20(WRAPPED_MATIC).balanceOf(msg.sender) >= _amount, "Not enough funds");

        uint256 cshareAmount = _amount * 125 / 100 / 1000; // 75%
        require(cshareAmount <= IERC20(cshare).balanceOf(address(this)), "Presale-CShare depleted");

        // Receive the MATIC
        IERC20(WRAPPED_MATIC).transferFrom(msg.sender, address(this), _amount);
        shareMatic += _amount;

        // TODO: Add liquidity
        // ...
        
        // Transfer the tokens
        IERC20(cshare).transfer(msg.sender, cshareAmount);
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
    // The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback in which they must pay any token0 or token1 owed for the liquidity
    function addLiquidity(AddLiquidityParams memory params) private returns (uint128 liquidity, uint256 amount0, uint256 amount1, IUniswapV3Pool pool) {
        // TODO: Check if pool exists
        // sharePool = IUniswapV3Factory(UNISWAP_FACTORY).createPool(WRAPPED_MATIC, cshare, 3000);

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