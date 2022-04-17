// SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.10;

import {MockOracle} from "./LemmaSwap/Mock/contracts/MockOracle.sol";
import {IMockOracle} from "./LemmaSwap/Mock/interfaces/IMockOracle.sol";
import {Denominations} from "./LemmaSwap/Mock/libs/Denominations.sol";

contract Deployment {
    MockOracle public oracle;
    
    constructor() {
        oracle = new MockOracle();
        oracle.setPriceNow(Denominations.ETH, Denominations.USD, 100);
    }
}


