// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {LemmaSwap} from "../LemmaSwap/LemmaSwap.sol";
import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";
import {Deployment, Collateral} from "../Contract.sol";
import "forge-std/Test.sol";

contract Minter {
    Deployment public d;

    constructor(Deployment _d) {
        d = _d;
        d.grantRole(address(this));
    }

    function mint(
        IERC20Decimals collateral,
        uint256 perpDEXIndex,
        uint256 amount
    ) external {
        d.askForMoney(address(collateral), amount);
        collateral.approve(address(d.usdl()), type(uint256).max);
        amount = (amount * 1e18) / (10**collateral.decimals());
        d.usdl().depositToWExactCollateral(
            address(this),
            amount,
            perpDEXIndex,
            0,
            collateral
        );
    }
}

contract ContractTest is Test {
    Deployment public d;
    bytes32 public constant FEES_TRANSFER_ROLE = keccak256("FEES_TRANSFER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    receive() external payable {}

    function setUp() public {
        d = new Deployment();
        TransferHelper.safeTransferETH(address(this), 100e18);
        TransferHelper.safeTransferETH(address(d), 100e18);
        d.deployTestnet(1);

        vm.startPrank(address(d));
        d.feesAccumulator().grantRole(FEES_TRANSFER_ROLE, address(this));
        vm.stopPrank();
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

        uint256 amountIn = 1e13;

        uint256[] memory amountsOut = d.lemmaSwap().swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        assertTrue(
            d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn
        );
        assertTrue(
            d.wbtc().balanceOf(address(this)) ==
                wbtcInitialBalance + amountsOut[1]
        );
    }

    function testDistributeFeesForEth() public {
        d.askForMoney(address(d.weth()), 1e12);
        d.askForMoney(address(d.wbtc()), 1e6);

        d.weth().transfer(address(d.feesAccumulator()), 1e12);
        d.wbtc().transfer(address(d.feesAccumulator()), 1e6);

        d.mockUniV3Router().setRouter(address(0));
        d.mockUniV3Router().setNextSwapAmount(1e9);

        uint256 balUsdlBefore = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthBefore = ILemmaSynth(d.getAddresses().LemmaSynthEth).balanceOf(d.getAddresses().xLemmaSynthEth);
        d.feesAccumulator().distibuteFees(address(d.weth()), 3000, 0);
        uint256 balUsdlAfter = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthAfter = ILemmaSynth(d.getAddresses().LemmaSynthEth)
            .balanceOf(d.getAddresses().xLemmaSynthEth);
        assertGt(balUsdlAfter, balUsdlBefore);
        assertGt(balSynthAfter, balSynthBefore);
    }

    function testDistributeFeesForBtc() public {
        d.askForMoney(address(d.weth()), 1e12);
        d.askForMoney(address(d.wbtc()), 1e6);

        d.weth().transfer(address(d.feesAccumulator()), 1e12);
        d.wbtc().transfer(address(d.feesAccumulator()), 1e6);

        d.mockUniV3Router().setRouter(address(0));
        d.mockUniV3Router().setNextSwapAmount(1e9);

        uint256 balUsdlBefore = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthBefore = ILemmaSynth(d.getAddresses().LemmaSynthBtc).balanceOf(d.getAddresses().xLemmaSynthBtc);
        d.feesAccumulator().distibuteFees(address(d.wbtc()), 3000, 0);
        uint256 balUsdlAfter = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthAfter = ILemmaSynth(d.getAddresses().LemmaSynthBtc)
            .balanceOf(d.getAddresses().xLemmaSynthBtc);
        assertGt(balUsdlAfter, balUsdlBefore);
        assertGt(balSynthAfter, balSynthBefore);
    }

    //TODO: this test is failing for some reason
    function testSwapExactETHForTokens() public {
        setUpForSwap();

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256 amountIn = 1e17;

        uint256[] memory amountsOut = d.lemmaSwap().swapExactETHForTokens{
            value: amountIn
        }(0, path, address(this), block.timestamp);

        assertTrue(
            d.wbtc().balanceOf(address(this)) ==
                wbtcInitialBalance + amountsOut[1]
        );
    }

    function swapExactTokensForETH() public {
        setUpForSwap();

        uint256 initialAmount = 10e18;

        d.askForMoney(address(d.wbtc()), initialAmount);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));
        uint256 ethInitialBalance = address(this).balance;

        d.wbtc().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.wbtc());
        path[1] = address(d.weth());

        uint256 amountIn = 43721400000000000; // 0.0437214 in form of 18 decimals

        uint256[] memory amountsOut = d.lemmaSwap().swapExactTokensForETH(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        assertTrue(
            d.wbtc().balanceOf(address(this)) == initialAmount - amountIn
        );
        assertTrue(
            d.weth().balanceOf(address(this)) == initialAmount + amountsOut[1]
        );
    }
}
