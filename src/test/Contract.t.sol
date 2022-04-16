// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "forge-std/console.sol";

contract ContractTest is DSTest {
    function setUp() public {}

    function testExample() public {
        uint256 test = 5656565656;
        console.log("The tx.origin is ", tx.origin);
        console.log("The msg.sender is ", msg.sender);
        console.log("The test is ", test + 1);
        assertTrue(true);
    }
}
