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
        if (!runTests["testSwapExactETHForTokens"]) {
            assertTrue(true);
            return;
        }

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
        if (!runTests["swapExactTokensForETH"]) {
            assertTrue(true);
            return;
        }

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
