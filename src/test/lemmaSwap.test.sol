// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";
import {Deployment, Collateral} from "../Contract.sol";
import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {LemmaSwap} from "../LemmaSwap/LemmaSwap.sol";
import "forge-std/console.sol";



contract Minter {
    Deployment public d; 
    constructor(Deployment _d) {
        d = _d;
    }

    function mint(IERC20 collateral, uint256 perpDEXIndex, uint256 amount) external {
        d.askForMoney(address(collateral), amount);
        collateral.approve(address(d.usdl()), type(uint256).max);
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

    receive() external payable {
        console.log("[ContractTest] Receive");
    }

    function setUp() public {
        d = new Deployment();
        TransferHelper.safeTransferETH(address(d), 100e18);

        d.deployTestnet(1);
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

    function testSwapExactTokensForTokens() public {
        setUpForSwap();

        d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256 amountIn = 10e3;

        d.lemmaSwap().swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            0
        );

        assertTrue( d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn );
        assertTrue( d.wbtc().balanceOf(address(this)) > 0 );
    }

    function testSwapExactETHForTokens() public {
        setUpForSwap();

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        address[] memory path = new address[](1);
        // path[0] = address(d.weth());
        path[0] = address(d.wbtc());

        uint256 amountIn = 10e3;

        d.lemmaSwap().swapExactETHForTokens{value: amountIn}(
            0,
            path,
            address(this),
            0
        );
        assertTrue( d.wbtc().balanceOf(address(this)) > 0 );
    }


    function swapExactTokensForETH() public {
        setUpForSwap();

        uint256 initialAmount = 10e18;

        d.askForMoney(address(d.wbtc()), initialAmount);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));
        uint256 ethInitialBalance = address(this).balance;

        d.wbtc().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](1);
        // path[0] = address(d.weth());
        path[0] = address(d.wbtc());

        uint256 amountIn = 10e2;

        d.lemmaSwap().swapExactTokensForETH(
            amountIn,
            0,
            path,
            address(this),
            0
        );

        assertTrue( d.wbtc().balanceOf(address(this)) == initialAmount - amountIn );
    }



}
