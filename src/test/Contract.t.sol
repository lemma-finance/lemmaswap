// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";
import {Deployment, Collateral} from "../Contract.sol";
import {MockOracle} from "../LemmaSwap/Mock/contracts/MockOracle.sol";
import {MockPerp} from "../LemmaSwap/Mock/contracts/MockPerp.sol";
import {Denominations} from "../LemmaSwap/Mock/libs/Denominations.sol";
import {MockLemmaTreasury, MockUSDL} from "../LemmaSwap/Mock/contracts/MockUSDL.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {LemmaSwap} from "../LemmaSwap/LemmaSwap.sol";
import {sToken} from "../interfaces/ILemmaRouter.sol";
import "forge-std/console.sol";



contract Minter {
    Deployment public d; 
    constructor(Deployment _d) {
        d = _d;
    }

    function mint(Collateral collateral, uint256 amount) external {
        d.askForMoney(address(collateral), amount);
        collateral.approve(address(d.usdl()), type(uint256).max);
        d.usdl().depositToWExactCollateral(
            address(this),
            amount,
            0,
            0,
            collateral
        );
    }
}

contract ContractTest is DSTest {

    Deployment public d;

    function setUp() public {
        d = new Deployment();
    }

    function testOracle() public {
        MockOracle oracle = d.oracle();
        uint256 priceNow = oracle.getPriceNow(address(d.weth()), Denominations.USD);
        console.log("Price Now is ", priceNow);
        assertTrue(priceNow == 100e18);
    }

    function testPerp() public {
        MockPerp perp = d.perp();
        uint256 amount = 1e18;
        uint256 expectedAmount = amount - (perp.feeOpenShort_1e6() * amount / 1e6);
        perp.openShort1XWExactCollateral(address(d.weth()), amount);
        assertTrue( perp.shorts(address(this), address(d.weth()), Denominations.USD) == expectedAmount );
    }


    function testMint() public {
        d.askForMoney(address(d.weth()), 10e18);
        d.weth().approve(address(d.usdl()), type(uint256).max);
        uint256 collateralAmount = 1e18;
        uint256 mintingFees = d.usdl().getFees(0, address(d.weth()), true);
        uint256 expectedUSDL = (collateralAmount - (collateralAmount * mintingFees / 1e6)) * d.usdl().price(address(d.weth())) / 1e18;
        d.usdl().depositToWExactCollateral(
            address(this),
            1e18,
            0,
            0,
            d.weth()
        );

        console.log("Minted USDL ", d.usdl().balanceOf(address(this)));
        console.log("Expected USDL ", expectedUSDL);

        assertTrue( d.usdl().balanceOf(address(this)) == expectedUSDL );
    }

    function testSwap() public {
        Minter m1 = new Minter(d);
        m1.mint(d.weth(), 10e18);

        Minter m2 = new Minter(d);
        m2.mint(d.wbtc(), 50e18);

        d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
        sToken memory tokenIn = sToken({
            token: d.weth(), 
            amount: 1e18
        });

        sToken memory tokenOut = sToken({
            token: d.wbtc(), 
            amount: 15e17
        });

        d.lemmaSwap().swapWithExactInputAndOutput(tokenIn, tokenOut);

        console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
        console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
        console.log("Final WETH Balance = ", d.usdl().balanceOf(address(this)));

        assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - tokenIn.amount );
        assertTrue( d.wbtc().balanceOf(address(this)) == wbtcInitialBalance + tokenOut.amount );
    }


    // function testExample() public {
    //     uint256 test = 5656565656;
    //     console.log("The tx.origin is ", tx.origin);
    //     console.log("The msg.sender is ", msg.sender);
    //     console.log("The test is ", test + 1);
    //     assertTrue(true);
    // }
}
