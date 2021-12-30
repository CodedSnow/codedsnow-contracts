// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ICOD.sol";
import "./interfaces/ITreasury.sol";

contract Presale {
    /* ========== STATE VARIABLES ========== */
    ICOD private immutable cod;
    address private immutable host;
    address private immutable treasury;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _cod, address _treasury) {
        cod = ICOD(_cod);

        host = msg.sender;
        treasury = _treasury;
    }

    /* ========== MODIFIERS ========== */
    modifier onlyHost() {
        require(msg.sender == host, "Host only.");
        _;
    }

    // TODO: Implement the presale functions
    function deposit() public payable {
        uint256 codAmount = msg.value / (2 * 10**9); // 50%
        cod.transfer(msg.sender, codAmount);
    }
}
