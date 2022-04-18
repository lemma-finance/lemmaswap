// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import "ds-test/test.sol";
import {Deployment} from "../Contract.sol";
import {MockOracle} from "../LemmaSwap/Mock/contracts/MockOracle.sol";
import {MockPerp} from "../LemmaSwap/Mock/contracts/MockPerp.sol";
import {Denominations} from "../LemmaSwap/Mock/libs/Denominations.sol";
import {MockLemmaTreasury, MockUSDL} from "../LemmaSwap/Mock/contracts/MockUSDL.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "forge-std/console.sol";

contract ContractTest is DSTest {
    Deployment public d;

    function setUp() public {
        d = new Deployment();
    }

    function testOracle() public {
        MockOracle oracle = d.oracle();
        uint256 priceNow = oracle.getPriceNow(address(d.collateral()), Denominations.USD);
        console.log("Price Now is ", priceNow);
        assertTrue(priceNow == 100);
    }

    function testPerp() public {
        MockPerp perp = d.perp();
        uint256 amount = 1e18;
        uint256 expectedAmount = amount - (perp.feeOpenShort_1e6() * amount / 1e6);
        perp.openShort1XWExactCollateral(address(d.collateral()), amount);
        assertTrue( perp.shorts(address(this), address(d.collateral()), Denominations.USD) == expectedAmount );
    }


    function testMint() public {
        MockUSDL usdl = d.usdl();
        uint256 priceCollateralUSD = 100e18;
        usdl.setPrice(address(d.collateral()), priceCollateralUSD);

        d.askForMoney(address(d.collateral()), 10e18);
        d.collateral().approve(address(usdl), type(uint256).max);

        uint256 collateralAmount = 1e18;
        uint256 mintingFees = usdl.getFees(0, address(d.collateral()), true);
        uint256 expectedUSDL = (collateralAmount - (collateralAmount * mintingFees / 1e6)) * priceCollateralUSD / 1e18;
        usdl.depositToWExactCollateral(
            address(this),
            1e18,
            0,
            0,
            d.collateral()
        );

        console.log("Minted USDL ", usdl.balanceOf(address(this)));
        console.log("Expected USDL ", expectedUSDL);

        assertTrue( usdl.balanceOf(address(this)) == expectedUSDL );
    }


    // function testExample() public {
    //     uint256 test = 5656565656;
    //     console.log("The tx.origin is ", tx.origin);
    //     console.log("The msg.sender is ", msg.sender);
    //     console.log("The test is ", test + 1);
    //     assertTrue(true);
    // }
}
