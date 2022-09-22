// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {LemmaSwap} from "../LemmaSwap/LemmaSwap.sol";
import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";
import {Deployment, Collateral} from "../Contract.sol";
import {IPerpVault} from "../interfaces/IPerpVault.sol";
import "forge-std/Test.sol";

interface IPerpLemma {
    function isUsdlCollateralTailAsset() external view returns (bool);

    function setIsUsdlCollateralTailAsset(bool _x) external;

    function getAccountValue() external view returns (int256 value_1e18);

    function getIndexPrice() external view returns (uint256 price);
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
        amount = (amount * 1e18) / (10 ** collateral.decimals());
        d.usdl().depositToWExactCollateral(address(this), amount, perpDEXIndex, 0, collateral);
    }
}

contract ContractTest is Test {
    Deployment public d;
    bytes32 public constant FEES_TRANSFER_ROLE = keccak256("FEES_TRANSFER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    receive() external payable {}

    modifier noAsstesLeft() {
        _;
        assertTrue(d.weth().balanceOf(address(d.lemmaSwap())) == 0);
        assertTrue(d.wbtc().balanceOf(address(d.lemmaSwap())) == 0);
    }

    function setUp() public {
        d = new Deployment();
        TransferHelper.safeTransferETH(address(this), 100e18);
        TransferHelper.safeTransferETH(address(d), 100e18);
        d.deployTestnet(1);

        address perpLemma = d.usdl().perpetualDEXWrappers(1, address(d.wbtc()));
        vm.startPrank(d.admin());
        IPerpLemma(perpLemma).setIsUsdlCollateralTailAsset(true);
        vm.stopPrank();

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

    // for e.g if we want to swap weth -> wbtc
    // then tokenIn => weth AND tokenOut => wbtc
    function getMaxAmountInUsedForFuzzing(
        uint256 tokenInIndex,
        uint256 tokenOutIndex,
        address tokenIn,
        address tokenOut
    )
        internal
        view
        returns (uint256)
    {
        address perpLemmaIn = d.usdl().perpetualDEXWrappers(tokenInIndex, tokenIn);
        address perpLemmaOut = d.usdl().perpetualDEXWrappers(tokenOutIndex, tokenOut);
        uint256 tokenOutDeposited;
        if (IPerpLemma(perpLemmaOut).isUsdlCollateralTailAsset()) {
            tokenOutDeposited = d.wbtc().balanceOf(perpLemmaOut);
        } else {
            int256 tempTokenOutDeposited = IPerpVault(d.perpVault()).getBalanceByToken(perpLemmaOut, tokenOut);
            tempTokenOutDeposited = tempTokenOutDeposited < 0 ? tempTokenOutDeposited * (-1) : tempTokenOutDeposited;
            tokenOutDeposited = uint256(tempTokenOutDeposited);
        }
        uint256 indexPriceOfTokenIn = IPerpLemma(perpLemmaIn).getIndexPrice();
        uint256 indexPriceOfTokenOut = IPerpLemma(perpLemmaOut).getIndexPrice();
        uint256 tokenOutDecimal = IERC20Decimals(address(d.wbtc())).decimals();
        tokenOutDeposited = (tokenOutDeposited * 1e18) / (10 ** tokenOutDecimal);
        uint256 totalUsdcInTermOfTokenOut = (uint256(tokenOutDeposited) * uint256(indexPriceOfTokenOut)) / 1e18;
        uint256 maxTokenInUsed = (totalUsdcInTermOfTokenOut * 1e18) / indexPriceOfTokenIn;
        return maxTokenInUsed;
    }

    function testSetupForSwap() public {
        setUpForSwap();
    }

    function testFailPayable() public {
        TransferHelper.safeTransferETH(address(d.lemmaSwap()), 1e18);
    }

    function testSwapExactTokensForTokens() public noAsstesLeft {
        setUpForSwap();

        d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256 amountIn = 1e13;

        uint256[] memory amountsOut =
            d.lemmaSwap().swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);

        console.log("amountsOut:", amountsOut[1]);

        assertTrue(d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn);
        assertTrue(d.wbtc().balanceOf(address(this)) == wbtcInitialBalance + amountsOut[1]);
    }

    function testSwapExactETHForTokens() public payable noAsstesLeft {
        setUpForSwap();

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256 amountIn = 1e13;

        uint256[] memory amountsOut =
            d.lemmaSwap().swapExactETHForTokens{value: amountIn}(0, path, address(this), block.timestamp);

        assertTrue(d.wbtc().balanceOf(address(this)) == wbtcInitialBalance + amountsOut[1]);
    }

    function testSwapExactTokensForETH() public noAsstesLeft {
        setUpForSwap();

        uint256 amountIn = 4372140; // 0.0437214 in form of 18 decimals
        d.bank().giveMoney(address(d.wbtc()), address(this), amountIn);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));
        uint256 ethInitialBalance = address(this).balance;

        d.wbtc().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.wbtc());
        path[1] = address(d.weth());

        uint256[] memory amountsOut = d.lemmaSwap().swapExactTokensForETH(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        assertTrue(
            d.wbtc().balanceOf(address(this)) == wbtcInitialBalance - amountIn
        );
        assertTrue(
            address(this).balance == ethInitialBalance + amountsOut[1]
        );
    }

    function testFuzzSwapExactTokensForTokens(uint256 amountIn) public {
        setUpForSwap();

        uint256 maxTokenInUsed = getMaxAmountInUsedForFuzzing(0, 1, address(d.weth()), address(d.wbtc()));
        vm.assume(amountIn > 1e6);
        vm.assume(amountIn < maxTokenInUsed);

        d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256[] memory amountsOut =
            d.lemmaSwap().swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);

        assertTrue(d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn);
        assertTrue(d.wbtc().balanceOf(address(this)) == wbtcInitialBalance + amountsOut[1]);
    }

    function testDistributeFeesForEth() public noAsstesLeft {
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
        uint256 balSynthAfter = ILemmaSynth(d.getAddresses().LemmaSynthEth).balanceOf(d.getAddresses().xLemmaSynthEth);
        assertGt(balUsdlAfter, balUsdlBefore);
        assertGt(balSynthAfter, balSynthBefore);
    }

    function testDistributeFeesForBtc() public noAsstesLeft {
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
        uint256 balSynthAfter = ILemmaSynth(d.getAddresses().LemmaSynthBtc).balanceOf(d.getAddresses().xLemmaSynthBtc);
        assertGt(balUsdlAfter, balUsdlBefore);
        assertGt(balSynthAfter, balSynthBefore);
    }
}
