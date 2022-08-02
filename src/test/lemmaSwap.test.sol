// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";
import {Deployment, Collateral} from "../Contract.sol";
import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {LemmaSwap} from "../LemmaSwap/LemmaSwap.sol";
import "forge-std/console.sol";

interface IERC20Decimals is IERC20 {
    function decimals() external view returns(uint256);
}

contract Minter {
    Deployment public d; 
    constructor(Deployment _d) {
        d = _d;
        d.grantRole(address(this));
    }

    function mint(IERC20Decimals collateral, uint256 perpDEXIndex, uint256 amount) external {
        d.askForMoney(address(collateral), amount);
        collateral.approve(address(d.usdl()), type(uint256).max);
        amount = amount * 1e18 / (10**collateral.decimals());
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
    receive() external payable {}

    function setUp() public {
        d = new Deployment();
        TransferHelper.safeTransferETH(address(this), 100e18);
        TransferHelper.safeTransferETH(address(d), 100e18);
        d.deployTestnet(1);
    }

    // Let's put some collateral 
    function setUpForSwap() public {
        // Trying to mint USDL with WETH
        Minter m1 = new Minter(d);
        m1.mint(IERC20Decimals(address(d.weth())), 0, 1e18); // 1 ether
        // Trying to mint USDL with WBTC
        Minter m2 = new Minter(d);
        m2.mint(IERC20Decimals(address(d.wbtc())), 1, 4374840); // 0.4374840 WBTC
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

        uint256 amountIn = 1e17;

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

        uint256 amountIn = 1e17;

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

        uint256 amountIn = 43721400000000000; // 0.0437214 in form of 18 decimals

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
