// SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.10;

import {MockOracle} from "./LemmaSwap/Mock/contracts/MockOracle.sol";
import {IMockOracle} from "./LemmaSwap/Mock/interfaces/IMockOracle.sol";
import {MockPerp} from "./LemmaSwap/Mock/contracts/MockPerp.sol";
import {Denominations} from "./LemmaSwap/Mock/libs/Denominations.sol";

contract Deployment {
    MockOracle public oracle;
    MockPerp public perp;
    
    constructor() {
        oracle = new MockOracle();
        oracle.setPriceNow(Denominations.ETH, Denominations.USD, 100);

        perp = new MockPerp(
            IMockOracle(address(oracle)),
            1000,   // feeOpenShort = 0.1% 
            1000    // feeCloseShort = 0.1%
        );
    }
}


