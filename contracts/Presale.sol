// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "./interfaces/ICOD.sol";
import "./interfaces/IDAI.sol";
import "./interfaces/ITreasury.sol";

contract Presale {
    /* ========== STATE VARIABLES ========== */
    ICOD private immutable cod;
    IDAI private immutable dai;
    address private immutable host;
    address private immutable treasury;

    /* ========== CONSTRUCTOR ========== */
    constructor(
        address _cod,
        address _dai,
        address _treasury
    ) {
        cod = ICOD(_cod);
        dai = IDAI(_dai);

        host = msg.sender;
        treasury = _treasury;
    }

    /* ========== MODIFIERS ========== */
    modifier onlyHost() {
        require(msg.sender == host, "Host only.");
        _;
    }

    // TODO: Implement the presale functions
}
