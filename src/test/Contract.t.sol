// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";
import {Deployment, Collateral} from "../Contract.sol";
import {MockOracle} from "../LemmaSwap/Mock/contracts/MockOracle.sol";
import {MockPerp} from "../LemmaSwap/Mock/contracts/MockPerp.sol";
import {Denominations} from "../LemmaSwap/Mock/libs/Denominations.sol";
import {MockLemmaTreasury, MockUSDL} from "../LemmaSwap/Mock/contracts/MockUSDL.sol";
import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {LemmaSwap} from "../LemmaSwap/LemmaSwap.sol";
import {sToken} from "../interfaces/ILemmaRouter.sol";
import "forge-std/console.sol";



contract Minter {
    Deployment public d; 
    constructor(Deployment _d) {
        d = _d;
    }

    function mint(IERC20 collateral, uint256 amount) external {
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

    // function testOracle() public {
    //     MockOracle oracle = d.oracle();
    //     uint256 priceNow = oracle.getPriceNow(address(d.weth()), Denominations.USD);
    //     console.log("Price Now is ", priceNow);
    //     assertTrue(priceNow == 100e18);
    // }

    // function testPerp() public {
    //     MockPerp perp = d.perp();
    //     uint256 amount = 1e18;
    //     uint256 expectedAmount = amount - (perp.feeOpenShort_1e6() * amount / 1e6);
    //     perp.openShort1XWExactCollateral(address(d.weth()), amount);
    //     assertTrue( perp.shorts(address(this), address(d.weth()), Denominations.USD) == expectedAmount );
    // }


    // function testMint() public {
    //     d.askForMoney(address(d.weth()), 10e18);
    //     d.weth().approve(address(d.usdl()), type(uint256).max);
    //     uint256 collateralAmount = 1e18;
    //     uint256 mintingFees = d.usdl().getFees(0, address(d.weth()), true);
    //     uint256 expectedUSDL = (collateralAmount - (collateralAmount * mintingFees / 1e6)) * d.usdl().price(address(d.weth())) / 1e18;
    //     d.usdl().depositToWExactCollateral(
    //         address(this),
    //         1e18,
    //         0,
    //         0,
    //         d.weth()
    //     );

    //     console.log("Minted USDL ", d.usdl().balanceOf(address(this)));
    //     console.log("Expected USDL ", expectedUSDL);

    //     assertTrue( d.usdl().balanceOf(address(this)) == expectedUSDL );
    // }

    // function testSwap1() public {
    //     Minter m1 = new Minter(d);
    //     m1.mint(d.weth(), 10e18);

    //     Minter m2 = new Minter(d);
    //     m2.mint(d.wbtc(), 50e18);

    //     d.askForMoney(address(d.weth()), 10e18);

    //     uint256 wethInitialBalance = d.weth().balanceOf(address(this));
    //     uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

    //     d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
    //     sToken memory tokenIn = sToken({
    //         token: d.weth(), 
    //         amount: 1e18
    //     });

    //     sToken memory tokenOut = sToken({
    //         token: d.wbtc(), 
    //         amount: 12e17
    //     });

    //     d.lemmaSwap().swapWithExactInputAndOutput(tokenIn, tokenOut, address(this));

    //     console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
    //     console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
    //     console.log("Final USDL Balance = ", d.usdl().balanceOf(address(this)));

    //     assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - tokenIn.amount );

    //     console.log("d.wbtc().balanceOf(address(this)) = ", d.wbtc().balanceOf(address(this))) ;
    //     console.log("wbtcInitialBalance = ", wbtcInitialBalance) ;
    //     console.log("tokenOut.amount = ", tokenOut.amount) ;
    //     console.log("wbtcInitialBalance + tokenOut.amount = ", wbtcInitialBalance + tokenOut.amount) ;

    //     // console.log("d.wbtc().balanceOf(address(this)) = %d, wbtcInitialBalance = %d, tokenOut.amount = %d, tot = %d", d.wbtc().balanceOf(address(this)), wbtcInitialBalance, tokenOut.amount, wbtcInitialBalance + tokenOut.amount) ;

    //     assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - tokenIn.amount );
    //     assertTrue( d.wbtc().balanceOf(address(this)) == wbtcInitialBalance + tokenOut.amount );
    // }


    // function testSwap2() public {
    //     Minter m1 = new Minter(d);
    //     m1.mint(d.weth(), 10e18);

    //     Minter m2 = new Minter(d);
    //     m2.mint(d.wbtc(), 50e18);

    //     d.askForMoney(address(d.weth()), 10e18);

    //     uint256 wethInitialBalance = d.weth().balanceOf(address(this));
    //     uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

    //     d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
    //     sToken memory tokenIn = sToken({
    //         token: d.weth(), 
    //         amount: 1e18
    //     });

    //     sToken memory tokenOut = sToken({
    //         token: d.wbtc(), 
    //         amount: 0
    //     });

    //     d.lemmaSwap().swapWithExactInput(tokenIn, tokenOut, address(this));

    //     console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
    //     console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
    //     console.log("Final WETH Balance = ", d.usdl().balanceOf(address(this)));

    //     assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - tokenIn.amount );

    //     console.log("d.wbtc().balanceOf(address(this)) = ", d.wbtc().balanceOf(address(this))) ;
    //     console.log("wbtcInitialBalance = ", wbtcInitialBalance) ;
    //     console.log("tokenOut.amount = ", tokenOut.amount) ;
    //     console.log("wbtcInitialBalance + tokenOut.amount = ", wbtcInitialBalance + tokenOut.amount) ;

    //     // console.log("d.wbtc().balanceOf(address(this)) = %d, wbtcInitialBalance = %d, tokenOut.amount = %d, tot = %d", d.wbtc().balanceOf(address(this)), wbtcInitialBalance, tokenOut.amount, wbtcInitialBalance + tokenOut.amount) ;

    //     assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - tokenIn.amount );
    //     assertTrue( d.wbtc().balanceOf(address(this)) == d.lemmaSwap().getAmountsOut(tokenIn, tokenOut) );
    // }


    // function testSwap3() public {
    //     Minter m1 = new Minter(d);
    //     m1.mint(d.weth(), 10e18);

    //     Minter m2 = new Minter(d);
    //     m2.mint(d.wbtc(), 50e18);

    //     d.askForMoney(address(d.weth()), 10e18);

    //     uint256 wethInitialBalance = d.weth().balanceOf(address(this));
    //     uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

    //     d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
    //     sToken memory tokenIn = sToken({
    //         token: d.weth(), 
    //         amount: 0
    //     });

    //     sToken memory tokenOut = sToken({
    //         token: d.wbtc(), 
    //         amount: 1e15
    //     });

    //     d.lemmaSwap().swapWithExactOutput(tokenIn, tokenOut, address(this));

    //     console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
    //     console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
    //     console.log("Final WETH Balance = ", d.usdl().balanceOf(address(this)));

    //     console.log("d.wbtc().balanceOf(address(this)) = ", d.wbtc().balanceOf(address(this))) ;
    //     console.log("wbtcInitialBalance = ", wbtcInitialBalance) ;
    //     console.log("tokenOut.amount = ", tokenOut.amount) ;
    //     console.log("wbtcInitialBalance + tokenOut.amount = ", wbtcInitialBalance + tokenOut.amount) ;

    //     // console.log("d.wbtc().balanceOf(address(this)) = %d, wbtcInitialBalance = %d, tokenOut.amount = %d, tot = %d", d.wbtc().balanceOf(address(this)), wbtcInitialBalance, tokenOut.amount, wbtcInitialBalance + tokenOut.amount) ;

    //     console.log("d.weth().balanceOf(address(this)) = ", d.weth().balanceOf(address(this)));
    //     console.log("wethInitialBalance = ", wethInitialBalance);
    //     console.log("d.lemmaSwap().getAmountsIn(tokenIn, tokenOut) = ", d.lemmaSwap().getAmountsIn(tokenIn, tokenOut));
    //     console.log("Delta = ", wethInitialBalance - d.lemmaSwap().getAmountsIn(tokenIn, tokenOut));

    //     assertTrue( d.weth().balanceOf(address(this)) == (wethInitialBalance - d.lemmaSwap().getAmountsIn(tokenIn, tokenOut)) );
    //     // assertTrue( d.wbtc().balanceOf(address(this)) == tokenOut.amount );
    // }




    // function testSwapExactTokensForTokens() public {
    //     Minter m1 = new Minter(d);
    //     m1.mint(d.weth(), 10e18);

    //     Minter m2 = new Minter(d);
    //     m2.mint(d.wbtc(), 50e18);

    //     d.askForMoney(address(d.weth()), 10e18);

    //     uint256 wethInitialBalance = d.weth().balanceOf(address(this));
    //     uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

    //     d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
    //     // sToken memory tokenIn = sToken({
    //     //     token: d.weth(), 
    //     //     amount: 0
    //     // });

    //     // sToken memory tokenOut = sToken({
    //     //     token: d.wbtc(), 
    //     //     amount: 1e15
    //     // });

    //     address[] memory path = new address[](2);
    //     path[0] = address(d.weth());
    //     path[1] = address(d.wbtc());

    //     uint256 amountIn = 1e18;
    //     uint256 expectedAmount = d.lemmaSwap().getAmountsOut(
    //         sToken({
    //             token: d.weth(),
    //             amount: amountIn
    //         }), 
    //         sToken({
    //             token: d.wbtc(),
    //             amount: 0
    //         })
    //     );

    //     d.lemmaSwap().swapExactTokensForTokens(
    //         amountIn,
    //         0,
    //         path,
    //         address(this),
    //         0
    //     );

    //     // console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
    //     // console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
    //     // console.log("Final WETH Balance = ", d.usdl().balanceOf(address(this)));

    //     // console.log("d.wbtc().balanceOf(address(this)) = ", d.wbtc().balanceOf(address(this)));
    //     // console.log("wbtcInitialBalance = ", wbtcInitialBalance);
    //     // console.log("tokenOut.amount = ", tokenOut.amount);
    //     // console.log("wbtcInitialBalance + tokenOut.amount = ", wbtcInitialBalance + tokenOut.amount);

    //     // console.log("d.wbtc().balanceOf(address(this)) = %d, wbtcInitialBalance = %d, tokenOut.amount = %d, tot = %d", d.wbtc().balanceOf(address(this)), wbtcInitialBalance, tokenOut.amount, wbtcInitialBalance + tokenOut.amount);

    //     // console.log("d.weth().balanceOf(address(this)) = ", d.weth().balanceOf(address(this)));
    //     // console.log("wethInitialBalance = ", wethInitialBalance);
    //     // console.log("d.lemmaSwap().getAmountsIn(tokenIn, tokenOut) = ", d.lemmaSwap().getAmountsIn(tokenIn, tokenOut));
    //     // console.log("Delta = ", wethInitialBalance - d.lemmaSwap().getAmountsIn(tokenIn, tokenOut));

    //     assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );
    //     assertTrue( d.wbtc().balanceOf(address(this)) == expectedAmount );
    // }



    function testSwapTokensForExactTokens() public {
        Minter m1 = new Minter(d);
        m1.mint(d.weth(), 10e18);

        Minter m2 = new Minter(d);
        m2.mint(d.wbtc(), 50e18);

        d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
        // sToken memory tokenIn = sToken({
        //     token: d.weth(), 
        //     amount: 0
        // });

        // sToken memory tokenOut = sToken({
        //     token: d.wbtc(), 
        //     amount: 1e15
        // });

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256 amountOut = 1e15;
        uint256 expectedAmount = amountOut;
        uint256 expectedAmountIn = d.lemmaSwap().getAmountsIn(
            sToken({
                token: d.weth(),
                amount: 0
            }), 
            sToken({
                token: d.wbtc(),
                amount: amountOut
            })
        );

        uint256 expectedAmountOut = d.lemmaSwap().getAmountsOut(
            sToken({
                token: d.weth(),
                amount: expectedAmountIn
            }), 
            sToken({
                token: d.wbtc(),
                amount: 0
            })
        );

        console.log("T333 expectedAmountOut = ", expectedAmountOut);
        console.log("T333 expectedAmount = ", expectedAmount);
        assertTrue( expectedAmountOut == expectedAmount );

        d.lemmaSwap().swapTokensForExactTokens(
            amountOut,
            type(uint256).max,
            path,
            address(this),
            0
        );

        console.log("d.wbtc().balanceOf(address(this)) ", d.wbtc().balanceOf(address(this)));
        console.log("wbtcInitialBalance ", wbtcInitialBalance);
        console.log("expectedAmount ", expectedAmount);

        // console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
        // console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
        // console.log("Final WETH Balance = ", d.usdl().balanceOf(address(this)));

        // console.log("d.wbtc().balanceOf(address(this)) = ", d.wbtc().balanceOf(address(this)));
        // console.log("wbtcInitialBalance = ", wbtcInitialBalance);
        // console.log("tokenOut.amount = ", tokenOut.amount);
        // console.log("wbtcInitialBalance + tokenOut.amount = ", wbtcInitialBalance + tokenOut.amount);

        // console.log("d.wbtc().balanceOf(address(this)) = %d, wbtcInitialBalance = %d, tokenOut.amount = %d, tot = %d", d.wbtc().balanceOf(address(this)), wbtcInitialBalance, tokenOut.amount, wbtcInitialBalance + tokenOut.amount);

        // console.log("d.weth().balanceOf(address(this)) = ", d.weth().balanceOf(address(this)));
        // console.log("wethInitialBalance = ", wethInitialBalance);
        // console.log("d.lemmaSwap().getAmountsIn(tokenIn, tokenOut) = ", d.lemmaSwap().getAmountsIn(tokenIn, tokenOut));
        // console.log("Delta = ", wethInitialBalance - d.lemmaSwap().getAmountsIn(tokenIn, tokenOut));

        assertTrue( d.weth().balanceOf(address(this)) == (wethInitialBalance - expectedAmountIn) );
        assertTrue( d.wbtc().balanceOf(address(this)) == (wbtcInitialBalance + expectedAmount) );
    }

    // function testExample() public {
    //     uint256 test = 5656565656;
    //     console.log("The tx.origin is ", tx.origin);
    //     console.log("The msg.sender is ", msg.sender);
    //     console.log("The test is ", test + 1);
    //     assertTrue(true);
    // }
}
