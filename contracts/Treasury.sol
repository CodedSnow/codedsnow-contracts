// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ITreasury.sol";
import "./interfaces/ICOD.sol";
import "./interfaces/IDAI.sol";
import "./interfaces/IERC20.sol";
import "./types/AccessControlled.sol";
import "./interfaces/IUniswapV2ERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20Metadata.sol";

contract Treasury is ITreasury, AccessControlled {
    /* ========== STATE VARIABLES ========== */
    ICOD private immutable cod;
    IDAI private immutable dai;

    /* ========== BONDING VARIABLES ========== */
    struct Bond {
        IERC20 principal; // token to accept as payment
        address swapAddr;
        uint256 maxDebt; // maxDebt remaining
        uint256 currentDebt; // total debt from bond
        uint256 vestingTerm; // In blocks
        uint256 minPayout;
        uint256 maxPayout;
        uint256 lastDecay; // last block when debt was decayed
    }
    mapping(uint256 => Bond) public bonds;
    uint256[] public bondIds; // bond IDs

    /* ========== ORDER VARIABLES ========== */
    struct Order {
        address receiver;
        uint256 amount; // Cod amount to receive
        uint256 expiry; // block number
    }
    mapping(uint256 => Order) public orders;
    uint256 private _nextOrderId;

    /* ========== MISC VARIABLES ========== */
    uint256 private _rewardAlloc; // 80% staking rewards, 20% validating rewards

    event PlacedOrder(uint256 indexed _id, address indexed _from);
    event RedeemedOrder(uint256 indexed _id);
    event GrantedAirdrop(address indexed _to, uint256 _amount);
    event AllocatedReward(address indexed _to, uint256 _amount);

    /* ========== CONSTRUCTOR ========== */
    constructor(
        address _cod,
        address _dai,
        address _authority
    ) AccessControlled(IAuthority(_authority)) {
        cod = ICOD(_cod);
        dai = IDAI(_dai);
    }

    /* ========== PRIV ONLY ========== */
    function grantAirdrop(address _to) external onlyGovernor {
        // TODO: Calculate aidrop amount and send the airdrop
    }

    function addBond(
        address _princinple,
        address _swapAddr,
        uint256 _maxDebt,
        uint256 _currentDebt,
        uint256 _vestingTerm,
        uint256 _minPayout,
        uint256 _maxPayout
    ) external onlyGuardian returns (uint256 _id) {
        uint256 _bondId = bondIds.length;

        bonds[_bondId] = Bond(
            IERC20(_princinple),
            _swapAddr,
            _maxDebt,
            _currentDebt,
            _vestingTerm,
            _minPayout,
            _maxPayout,
            block.number
        );

        bondIds.push(_bondId);

        return _bondId;
    }

    function deprecateBond(uint256 _id) external onlyGuardian {
        bonds[_id].maxDebt = 0;
    }

    /* ========== VAULT ========== */
    function updateAlloc(uint256 _amount) external onlyVault {
        _rewardAlloc -= _amount;
    }

    // 7 day reward allocation (80% staking, 20% validating)
    function rewardAlloc() external view returns (uint256) {
        return _rewardAlloc;
    }

    /* ========== INTERACTIONS ========== */
    function bond(
        uint256 _bondId,
        address _to,
        uint256 _amount
    ) external returns (uint256) {
        require(_amount >= bonds[_bondId].minPayout && _amount <= bonds[_bondId].maxPayout, "Invalid amount");

        decayDebt(_bondId);
        require(_amount <= (bonds[_bondId].maxDebt - bonds[_bondId].currentDebt), "Exceeded max debt");

        bonds[_bondId].principal.transferFrom(msg.sender, address(this), _amount);
        bonds[_bondId].currentDebt += _amount;

        // Deterministism for rewards
        uint256 marketPrice = tokenPrice(bonds[_bondId].swapAddr, bonds[_bondId].principal);
        uint256 dMarketPrice = (marketPrice * (bonds[_bondId].currentDebt / (bonds[_bondId].maxDebt + bonds[_bondId].currentDebt))) / 100;

        uint256 codAmount = _amount / dMarketPrice;
        uint256 codMintAmount = (codAmount * 30) / 100; // 30% for reward allocation

        cod.mint(address(this), codMintAmount);
        _rewardAlloc += codMintAmount;

        uint256 orderId = _nextOrderId;
        _nextOrderId++;

        uint256 expiry = block.number + bonds[_bondId].vestingTerm;

        orders[orderId] = Order(_to, codAmount, expiry);
        emit OrderCreated(orderId, _to, _bondId, codAmount, expiry);

        return orderId;
    }

    function claim(uint256 _id) external {
        // Checks
        Order memory selOrder = orders[_id];
        require(msg.sender == selOrder.receiver, "Not your order");
        require(selOrder.expiry <= block.number, "Vesting period active");
        // Effect
        delete orders[_id];
        emit OrderClaimed(_id, selOrder.receiver, selOrder.amount);
        // Interaction
        cod.mint(msg.sender, selOrder.amount);
    }

    function tokenPrice(address _swapAddr, IERC20 _principal)
        public
        view
        returns (uint256 price_)
    {
        IUniswapV2Pair _swapPair = IUniswapV2Pair(_swapAddr);
        if (_swapAddr == address(0)) {
            // TODO:
            // Get the price of principal in USD
            // Get the price of cod in USD
            // Get the price of principal in cod
            price_ = 10**IERC20Metadata(address(cod)).decimals() / 10**IERC20Metadata(address(_principal)).decimals();
        } else {
            // Example: How much USD/DAI is one COD?
            (uint256 reserve0, uint256 reserve1, ) = _swapPair.getReserves();

            uint256 reserve;
            if (_swapPair.token0() == address(cod)) {
                reserve = reserve1;
            } else {
                require(_swapPair.token1() == address(cod), "Invalid pair");
                reserve = reserve0;
            }

            // Hopefull 12 in the beginning
            price_ = (reserve * 2 * (10**IERC20Metadata(address(cod)).decimals())) / getTotalValue(_swapPair);
        }
    }

    /* ======== INTERNAL FUNCTIONS ======== */
    function sqrrt(uint256 a) internal pure returns (uint256 c) {
        if (a > 3) {
            c = a;
            uint256 b = (a / 2) + 1;
            while (b < c) {
                c = b;
                b = ((a / b) + b) / 2;
            }
        } else if (a != 0) {
            c = 1;
        }
    }

    function getTotalValue(IUniswapV2Pair _swapPair) public view returns (uint256 value_) {
        uint256 token0 = IERC20Metadata(_swapPair.token0()).decimals();
        uint256 token1 = IERC20Metadata(_swapPair.token1()).decimals();

        uint256 decimals = (token0 + token1) / IERC20Metadata(address(_swapPair)).decimals();
        (uint256 reserve0, uint256 reserve1, ) = _swapPair.getReserves();

        value_ = sqrrt((reserve0 * reserve1) / 10**decimals) * 2;
    }

    function decayDebt(uint256 _bondId) internal {
        Bond memory tmpBond = bonds[_bondId];

        // Multiply the current debt by the blocks we missed devided by the vesting term
        uint256 decay = (tmpBond.currentDebt * (block.number - tmpBond.lastDecay)) / tmpBond.vestingTerm;

        if (decay > tmpBond.currentDebt) {
            decay = tmpBond.currentDebt;
        }

        // Set the new values
        bonds[_bondId].currentDebt = bonds[_bondId].currentDebt - decay;
        bonds[_bondId].lastDecay = block.number;
    }
}
