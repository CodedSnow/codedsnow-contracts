// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ITreasury.sol";
import "./interfaces/ICOD.sol";
import "./interfaces/IDAI.sol";

contract Treasury is ITreasury {
    /* ========== STATE VARIABLES ========== */
    address private founder;
    address private vault;

    ICOD private immutable cod;
    IDAI private immutable dai;

    struct Order {
        address receiver;
        uint256 amount;
        uint claimable;
    }
    mapping(uint256 => Order) public orders;
    uint256 private nextOrderId;
    uint256 public totalOrderAmount;

    uint8 private _orderDiscount; // Order discount in perc
    uint256 private _rewardAlloc; // 80% staking rewards, 20% validating rewards

    event PlacedOrder(uint256 indexed _id, address indexed _from);
    event RedeemedOrder(uint256 indexed _id);
    event GrantedAirdrop(address indexed _to, uint256 _amount);
    event AllocatedReward(address indexed _to, uint256 _amount);

    /* ========== CONSTRUCTOR ========== */
    constructor(address _cod, address _dai) {
        founder = msg.sender;
        cod = ICOD(_cod);
        dai = IDAI(_dai);

        _orderDiscount = 25;
    }

    /* ========== MODIFIERS ========== */
    modifier onlyFounder {
        require(msg.sender == founder, "Founder only.");
        _;
    }

    modifier onlyVault {
        require(msg.sender == vault, "Vault only.");
        _;
    }

    /* ========== ONLY FOUNDER ========== */
    function setVault(address account_) external onlyFounder {
        require(vault == address(0), "Vault can only be set once.");
        vault = account_;
    }

    function grantAirdrop(address _to) external onlyFounder {
        // TODO: Calculate aidrop amount and send the airdrop
    }

    /* ========== VAULT ========== */
    function updateAlloc(uint256 _amount) external onlyVault {
        _rewardAlloc -= _amount;
    }

    function rewardAlloc() external view returns (uint256) {
        return _rewardAlloc;
    }

    /* ========== INTERACTIONS ========== */
    function placeOrder(address _to, uint256 _daiAmount) external {
        require(_daiAmount >= 15 ether, "Atleast 15 DAI is required.");

        // Market price of 1 COD in DAI.
        uint256 mpDAI = 12/*price*/ * (10**9); // 100% of MP (Example)
        // Discounted market price for 1 COD in DAI.
        uint256 dmpDAI = mpDAI / 100 * (100 - _orderDiscount); // 75% of MP (Example)

        // Amount of COD that will be ordered
        uint256 codAmount = _daiAmount / dmpDAI;

        // Remove the DAI and mint to treasury
        dai.transferFrom(msg.sender, address(this), _daiAmount);
        cod.mint(address(this), codAmount);

        // Include the freshly minted rewards in the allocation
        _rewardAlloc += (mpDAI - dmpDAI) * codAmount;

        // Queue the order given the ID.
        orders[nextOrderId] = Order(
            _to,
            codAmount,
            block.timestamp + 5 days
        );

        // Update total order amount
        totalOrderAmount += codAmount;
        emit PlacedOrder(nextOrderId, msg.sender);

        nextOrderId++;
    }

    // Redeem your order based on id
    function redeemOrder(uint256 _id) external {
        require(orders[_id].receiver == msg.sender, "Not your order.");
        require(orders[_id].claimable < block.timestamp, "Lock period active.");

        uint256 _amount = orders[_id].amount;
        // Handle local data
        delete orders[_id];
        totalOrderAmount -= _amount;
        emit RedeemedOrder(_id);
        // Mint the order
        cod.mint(msg.sender, _amount);
    }
}