// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import "ds-test/test.sol";
import {Deployment} from "../Contract.sol";
import {MockOracle} from "../LemmaSwap/Mock/contracts/MockOracle.sol";
import {Denominations} from "../LemmaSwap/Mock/libs/Denominations.sol";
import "forge-std/console.sol";

contract ContractTest is DSTest {
    Deployment public d;

    function setUp() public {
        d = new Deployment();
    }

    function testOracle() public {
        MockOracle oracle = d.oracle();
        uint256 priceNow = oracle.getPriceNow(Denominations.ETH, Denominations.USD);
        console.log("Price Now is ", priceNow);
        assertTrue(priceNow == 100);
    }

    // function testExample() public {
    //     uint256 test = 5656565656;
    //     console.log("The tx.origin is ", tx.origin);
    //     console.log("The msg.sender is ", msg.sender);
    //     console.log("The test is ", test + 1);
    //     assertTrue(true);
    // }
}
