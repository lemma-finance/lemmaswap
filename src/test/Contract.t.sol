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

    function mint(IERC20 collateral, uint256 perpDEXIndex, uint256 amount) external {
        d.askForMoney(address(collateral), amount);
        collateral.approve(address(d.usdl()), type(uint256).max);
        // console.log("T1 ", d.usdl().perpetualDEXWrappers(0, ))
        d.usdl().depositToWExactCollateral(
            address(this),
            amount,
            perpDEXIndex,
            0,
            address(collateral)
        );
    }
}

contract ContractTest is DSTest {

    Deployment public d;
    mapping(string => bool) public runTests;

    // 0 --> Local Deploy 
    // 1 --> Optimism Kovan
    uint256 mode;

    constructor() DSTest() {
        runTests["testOracle"]                              =       true;
        runTests["testPerp"]                                =       true;
        runTests["testMint"]                                =       true;
        runTests["testSwap1"]                               =       true;
        runTests["testSwap2"]                               =       true;
        runTests["testSwap3"]                               =       true;
        runTests["testSwapExactTokensForTokens"]            =       true;
        runTests["testSwapTokensForExactTokens"]            =       true;
        runTests["testSwapExactETHForTokens"]               =       true;
        runTests["testswapTokensForExactETH"]               =       true;        
        runTests["testSwapExactTokensForETH"]               =       true; 
        runTests["testSwapETHForExactTokens"]               =       true; 

        mode = 1;
        
    }

    receive() external payable {
        console.log("[ContractTest] Receive");
        // assert(msg.sender == address(weth)); // only accept ETH via fallback from the WETH contract
    }

    function setUp() public {
        d = new Deployment();
        TransferHelper.safeTransferETH(address(d), 100e18);

        if(mode == 0) {
            d.deployLocal();
        } else {
            d.deployTestnet(mode);
        }

    }

    // Let's put some collateral 
    function setUpForSwap() public {
        console.log("[setUpForSwap()] Trying to mint USDL with WETH");
        Minter m1 = new Minter(d);
        m1.mint(d.weth(), 0, 10e18);
        console.log("[setUpForSwap()] Minting with WETH Done");

        console.log("[setUpForSwap()] Trying to mint USDL with WBTC");
        Minter m2 = new Minter(d);

        // NOTE: Using >= 10e4 results in a pretty weird 
        // [FAIL. Reason: SafeMath: subtraction overflow] testSetupForSwap() (gas: 535585)
        // Need to investigate it later
        m2.mint(d.wbtc(), 1, 10e3);
        console.log("[setUpForSwap()] Minting with WBTC Done");
    }

    function testSetupForSwap() public {
        setUpForSwap();
    }

    function testPayable() public {
        TransferHelper.safeTransferETH(address(d.lemmaSwap()), 1e18);
    }

    // function testOracle() public {
    //     if (!runTests["testOracle"]) {
    //         assertTrue(true);
    //         return;
    //     }

    //     MockOracle oracle = d.oracle();
    //     uint256 priceNow = oracle.getPriceNow(address(d.weth()), Denominations.USD);
    //     console.log("Price Now is ", priceNow);
    //     assertTrue(priceNow == 100e18);
    // }

    // function testPerp() public {
    //     if (!runTests["testPerp"]) {
    //         assertTrue(true);
    //         return;
    //     }

    //     MockPerp perp = d.perp();
    //     uint256 amount = 1e18;
    //     uint256 expectedAmount = amount - (perp.feeOpenShort_1e6() * amount / 1e6);
    //     perp.openShort1XWExactCollateral(address(d.weth()), amount);
    //     assertTrue( perp.shorts(address(this), address(d.weth()), Denominations.USD) == expectedAmount );
    // }


    // function testMint() public {
    //     if (!runTests["testMint"]) {
    //         assertTrue(true);
    //         return;
    //     }
    //     d.askForMoney(address(d.weth()), 10e18);
    //     d.weth().approve(address(d.usdl()), type(uint256).max);
    //     uint256 collateralAmount = 1e18;

    //     // TODO: Fix
    //     uint256 mintingFees = 0;
    //     // uint256 mintingFees = d.usdl().getFees(0, address(d.weth()), true);
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


    function testSwap1() public {
        if (!runTests["testSwap1"]) {
            assertTrue(true);
            return;
        }

        setUpForSwap();

        d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
        // sToken memory tokenIn = sToken({
        //     token: d.weth(), 
        //     amount: 10e18
        // });

        // // NOTE: WBTC has probably 8 decimals also on Optimism Kovan Chain 
        // sToken memory tokenOut = sToken({
        //     token: d.wbtc(), 
        //     amount: 10e2
        // });

        address tokenIn = address(d.weth());
        uint256 amountIn = 10e18;
        address tokenOut = address(d.wbtc());
        uint256 amountOut = 10e2;

        d.lemmaSwap().swapWithExactInputAndOutput(tokenIn, amountIn, tokenOut, amountOut, address(this));
        // d.lemmaSwap().swapWithExactInputAndOutput(tokenIn, tokenOut, address(this));

        console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
        console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
        console.log("Final USDL Balance = ", d.usdl().balanceOf(address(this)));

        assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );

        console.log("d.wbtc().balanceOf(address(this)) = ", d.wbtc().balanceOf(address(this))) ;
        console.log("wbtcInitialBalance = ", wbtcInitialBalance) ;
        console.log("tokenOut.amount = ", amountOut) ;
        console.log("wbtcInitialBalance + tokenOut.amount = ", wbtcInitialBalance + amountOut);

        // console.log("d.wbtc().balanceOf(address(this)) = %d, wbtcInitialBalance = %d, tokenOut.amount = %d, tot = %d", d.wbtc().balanceOf(address(this)), wbtcInitialBalance, tokenOut.amount, wbtcInitialBalance + tokenOut.amount) ;

        assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );
        assertTrue( d.wbtc().balanceOf(address(this)) == wbtcInitialBalance + amountOut );
    }


    function testSwap2() public {
        if (!runTests["testSwap2"]) {
            assertTrue(true);
            return;
        }


        console.log("[testSwap2()] Start");

        setUpForSwap();

        console.log("[testSwap2()] Setup for Swap DONE");

        d.askForMoney(address(d.weth()), 10e18);

        console.log("[testSwap2()] Money Received");

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        console.log("[testSwap2()] Initial WETH Balance ", wethInitialBalance);
        console.log("[testSwap2()] Initial WBTC Balance ", wbtcInitialBalance);

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);
        // sToken memory tokenIn = sToken({
        //     token: d.weth(), 
        //     amount: 10e3
        // });

        // sToken memory tokenOut = sToken({
        //     token: d.wbtc(), 
        //     amount: 0
        // });

        address tokenIn = address(d.weth());
        uint256 amountIn = 10e3;
        address tokenOut = address(d.wbtc());
        uint256 amountOut = 0;

        d.lemmaSwap().swapWithExactInput(tokenIn, amountIn, tokenOut, amountOut, address(this));
        // d.lemmaSwap().swapWithExactInput(tokenIn, tokenOut, address(this));

        console.log("Final WETH Balance = ", d.weth().balanceOf(address(this)));
        console.log("Final WBTC Balance = ", d.wbtc().balanceOf(address(this)));
        console.log("Final WETH Balance = ", d.usdl().balanceOf(address(this)));

        assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );

        console.log("d.wbtc().balanceOf(address(this)) = ", d.wbtc().balanceOf(address(this))) ;
        console.log("wbtcInitialBalance = ", wbtcInitialBalance) ;
        console.log("tokenOut.amount = ", amountOut);
        console.log("wbtcInitialBalance + tokenOut.amount = ", wbtcInitialBalance + amountOut);

        // console.log("d.wbtc().balanceOf(address(this)) = %d, wbtcInitialBalance = %d, tokenOut.amount = %d, tot = %d", d.wbtc().balanceOf(address(this)), wbtcInitialBalance, tokenOut.amount, wbtcInitialBalance + tokenOut.amount) ;

        assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );

        // if(d.useQuoter()) {
        //     assertTrue( d.wbtc().balanceOf(address(this)) == d.lemmaSwap().getAmountsOut(tokenIn, tokenOut) );
        // }

    }


    // function testSwap3() public {
    //     if (!runTests["testSwap3"]) {
    //         assertTrue(true);
    //         return;
    //     }

    //     setUpForSwap();

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
    //         amount: 10e2
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





    function testSwapExactTokensForTokens() public {
        if (!runTests["testSwapExactTokensForTokens"]) {
            assertTrue(true);
            return;
        }

        setUpForSwap();

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

        uint256 amountIn = 1e18;
        // uint256 expectedAmount = d.lemmaSwap().getAmountsOut(
        //     sToken({
        //         token: d.weth(),
        //         amount: amountIn
        //     }), 
        //     sToken({
        //         token: d.wbtc(),
        //         amount: 0
        //     })
        // );

        d.lemmaSwap().swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            0
        );

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

        assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );
        // assertTrue( d.wbtc().balanceOf(address(this)) == expectedAmount );
    }



    // function testswapTokensForExactTokens() public {
    //     if (!runTests["testswapTokensForExactTokens"]) {
    //         assertTrue(true);
    //         return;
    //     }

    //     setUpForSwap();

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

    //     uint256 amountOut = 1e15;
    //     uint256 expectedAmount = amountOut;
    //     uint256 expectedAmountIn = d.lemmaSwap().getAmountsIn(
    //         sToken({
    //             token: d.weth(),
    //             amount: 0
    //         }), 
    //         sToken({
    //             token: d.wbtc(),
    //             amount: amountOut
    //         })
    //     );

    //     uint256 expectedAmountOut = d.lemmaSwap().getAmountsOut(
    //         sToken({
    //             token: d.weth(),
    //             amount: expectedAmountIn
    //         }), 
    //         sToken({
    //             token: d.wbtc(),
    //             amount: 0
    //         })
    //     );

    //     console.log("T333 expectedAmountOut = ", expectedAmountOut);
    //     console.log("T333 expectedAmount = ", expectedAmount);
    //     assertTrue( expectedAmountOut == expectedAmount );

    //     d.lemmaSwap().swapTokensForExactTokens(
    //         amountOut,
    //         type(uint256).max,
    //         path,
    //         address(this),
    //         0
    //     );

    //     console.log("d.wbtc().balanceOf(address(this)) ", d.wbtc().balanceOf(address(this)));
    //     console.log("wbtcInitialBalance ", wbtcInitialBalance);
    //     console.log("expectedAmount ", expectedAmount);

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

    //     assertTrue( d.weth().balanceOf(address(this)) == (wethInitialBalance - expectedAmountIn) );
    //     assertTrue( d.wbtc().balanceOf(address(this)) == (wbtcInitialBalance + expectedAmount) );
    // }




    // function testExample() public {
    //     uint256 test = 5656565656;
    //     console.log("The tx.origin is ", tx.origin);
    //     console.log("The msg.sender is ", msg.sender);
    //     console.log("The test is ", test + 1);
    //     assertTrue(true);
    // }


    function testSwapExactETHForTokens() public {
        if (!runTests["testSwapExactETHForTokens"]) {
            assertTrue(true);
            return;
        }

        setUpForSwap();

        // d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        // d.weth().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](1);
        // path[0] = address(d.weth());
        path[0] = address(d.wbtc());

        uint256 amountIn = 1e18;
        // uint256 expectedAmount = d.lemmaSwap().getAmountsOut(
        //     sToken({
        //         token: d.weth(),
        //         amount: amountIn
        //     }), 
        //     sToken({
        //         token: d.wbtc(),
        //         amount: 0
        //     })
        // );

        d.lemmaSwap().swapExactETHForTokens{value: amountIn}(
            0,
            path,
            address(this),
            0
        );

        // assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );
        // assertTrue( d.wbtc().balanceOf(address(this)) == expectedAmount );
    }


    // function testSwapTokensForExactETH() public {
    //     if (!runTests["testSwapTokensForExactETH"]) {
    //         assertTrue(true);
    //         return;
    //     }

    //     setUpForSwap();

    //     d.askForMoney(address(d.wbtc()), 10e18);

    //     uint256 wethInitialBalance = d.weth().balanceOf(address(this));
    //     uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));
    //     uint256 ethInitialBalance = address(this).balance;

    //     d.wbtc().approve(address(d.lemmaSwap()), type(uint256).max);
    //     // sToken memory tokenIn = sToken({
    //     //     token: d.weth(), 
    //     //     amount: 0
    //     // });

    //     // sToken memory tokenOut = sToken({
    //     //     token: d.wbtc(), 
    //     //     amount: 1e15
    //     // });

    //     address[] memory path = new address[](1);
    //     // path[0] = address(d.weth());
    //     path[0] = address(d.wbtc());

    //     uint256 amountOut = 1e15;
    //     uint256 expectedAmount = amountOut;
    //     // uint256 expectedAmountIn = d.lemmaSwap().getAmountsIn(
    //     //     sToken({
    //     //         token: d.weth(),
    //     //         amount: 0
    //     //     }), 
    //     //     sToken({
    //     //         token: d.wbtc(),
    //     //         amount: amountOut
    //     //     })
    //     // );

    //     // uint256 expectedAmountOut = d.lemmaSwap().getAmountsOut(
    //     //     sToken({
    //     //         token: d.weth(),
    //     //         amount: expectedAmountIn
    //     //     }), 
    //     //     sToken({
    //     //         token: d.wbtc(),
    //     //         amount: 0
    //     //     })
    //     // );

    //     // console.log("T333 expectedAmountOut = ", expectedAmountOut);
    //     // console.log("T333 expectedAmount = ", expectedAmount);
    //     // assertTrue( expectedAmountOut == expectedAmount );

    //     d.lemmaSwap().swapTokensForExactETH(
    //         amountOut,
    //         type(uint256).max,
    //         path,
    //         address(this),
    //         0
    //     );

    //     console.log("d.wbtc().balanceOf(address(this)) ", d.wbtc().balanceOf(address(this)));
    //     console.log("wbtcInitialBalance ", wbtcInitialBalance);
    //     console.log("expectedAmount ", expectedAmount);

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

    //     // assertTrue( d.weth().balanceOf(address(this)) == (wethInitialBalance - expectedAmountIn) );
    //     // assertTrue( d.wbtc().balanceOf(address(this)) == (wbtcInitialBalance + expectedAmount) );
    //     assertTrue( address(this).balance == ethInitialBalance + expectedAmount );
    // }



    function swapExactTokensForETH() public {
        if (!runTests["swapExactTokensForETH"]) {
            assertTrue(true);
            return;
        }

        setUpForSwap();

        d.askForMoney(address(d.wbtc()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));
        uint256 ethInitialBalance = address(this).balance;

        d.wbtc().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](1);
        // path[0] = address(d.weth());
        path[0] = address(d.wbtc());

        uint256 amountIn = 1e18;
        // uint256 expectedAmount = d.lemmaSwap().getAmountsOut(
        //     sToken({
        //         token: d.wbtc(),
        //         amount: amountIn
        //     }), 
        //     sToken({
        //         token: d.weth(),
        //         amount: 0
        //     })
        // );

        d.lemmaSwap().swapExactTokensForETH(
            amountIn,
            0,
            path,
            address(this),
            0
        );

        // assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );
        assertTrue( d.wbtc().balanceOf(address(this)) == 10e18 - amountIn );
        // assertTrue( address(this).balance == ethInitialBalance + expectedAmount );
    }







    // function testSwapETHForExactTokens() public {
    //     if (!runTests["testSwapETHForExactTokens"]) {
    //         assertTrue(true);
    //         return;
    //     }

    //     setUpForSwap();

    //     // d.askForMoney(address(d.wbtc()), 10e18);

    //     uint256 wethInitialBalance = d.weth().balanceOf(address(this));
    //     uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

    //     // d.wbtc().approve(address(d.lemmaSwap()), type(uint256).max);

    //     address[] memory path = new address[](1);
    //     // path[0] = address(d.weth());
    //     path[0] = address(d.wbtc());

    //     uint256 amountInMax = 10e18;

    //     uint256 amountOut = 1e15;
    //     uint256 expectedAmount = amountOut;
    //     // uint256 expectedAmountIn = d.lemmaSwap().getAmountsIn(
    //     //     sToken({
    //     //         token: d.weth(),
    //     //         amount: 0
    //     //     }), 
    //     //     sToken({
    //     //         token: d.wbtc(),
    //     //         amount: amountOut
    //     //     })
    //     // );

    //     // uint256 expectedAmountOut = d.lemmaSwap().getAmountsOut(
    //     //     sToken({
    //     //         token: d.weth(),
    //     //         amount: expectedAmountIn
    //     //     }), 
    //     //     sToken({
    //     //         token: d.wbtc(),
    //     //         amount: 0
    //     //     })
    //     // );

    //     // console.log("T333 expectedAmountOut = ", expectedAmountOut);
    //     // console.log("T333 expectedAmount = ", expectedAmount);
    //     // assertTrue( expectedAmountOut == expectedAmount );

    //     d.lemmaSwap().swapETHForExactTokens{value: amountInMax}(
    //         amountOut,
    //         path,
    //         address(this),
    //         0
    //     );

    //     console.log("d.wbtc().balanceOf(address(this)) ", d.wbtc().balanceOf(address(this)));
    //     console.log("wbtcInitialBalance ", wbtcInitialBalance);
    //     console.log("expectedAmount ", expectedAmount);

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

    //     // assertTrue( d.weth().balanceOf(address(this)) == (wethInitialBalance - expectedAmountIn) );
    //     assertTrue( d.wbtc().balanceOf(address(this)) == (wbtcInitialBalance + expectedAmount) );
    // }






}
