// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {LemmaSwap} from "../LemmaSwap/LemmaSwap.sol";
import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";
import {Deployment, Collateral, MockSwapRouter} from "./Contract_LV1.sol";
import {IPerpVault} from "../interfaces/IPerpVault.sol";
import "../interfaces/IXUSDL.sol";
import "../interfaces/IXLemmaSynth.sol";
import "forge-std/Test.sol";

interface IPerpLemma {
    function isUsdlCollateralTailAsset() external view returns (bool);

    function setIsUsdlCollateralTailAsset(bool _x) external;

    function getAccountValue() external view returns (int256 value_1e18);

    function getIndexPrice() external view returns (uint256 price);

    function grantRole(bytes32 role, address account) external;

    function depositSettlementToken(uint256 _amount) external;
}

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
    bytes32 public constant FEES_TRANSFER_ROLE =
        keccak256("FEES_TRANSFER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant USDC_TREASURY = keccak256("USDC_TREASURY");

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

        address perpLemma = d.usdl().perpetualDEXWrappers(0, address(d.wbtc()));
        vm.startPrank(d.admin());
        IPerpLemma(perpLemma).setIsUsdlCollateralTailAsset(true);
        vm.stopPrank();

        vm.startPrank(address(d));
        d.feesAccumulator().grantRole(FEES_TRANSFER_ROLE, address(this));
        vm.stopPrank();
    }

    function _getMoneyForTo(address to, address token, uint256 amount) internal {
        d.bank().giveMoney(token, to, amount);
        assertTrue(IERC20Decimals(token).balanceOf(to) >= amount);
    }

    function _mintUSDLWExactCollateralNoChecks(address to, address collateral, uint256 amount) internal {
        console.log("[_mintUSDLWExactCollateralNoChecks()] Start");
        address usdl = address(d.usdl());
        _getMoneyForTo(to, collateral, amount);
        uint256 beforeBalanceUSDL = IERC20Decimals(usdl).balanceOf(to);
        uint256 beforeBalanceCollateral = IERC20Decimals(collateral).balanceOf(to);
        IERC20Decimals(collateral).approve(usdl, type(uint256).max);
        // uint256 beforeTotalUsdl = d.pl().mintedPositionUsdlForThisWrapper();
        // 4th param is minUSDLToMint which is need to be set using callStatic, currently set 0 for not breaking revert
        // calsstatic is not possible in solidity so
        d.usdl().depositToWExactCollateral(to, amount, 0, 0, IERC20Decimals(collateral));
        console.log("[_mintUSDLWExactCollateralNoChecks()] End");
        // uint256 afterTotalUsdl = d.pl().mintedPositionUsdlForThisWrapper();
        // uint256 afterBalanceUSDL = IERC20Decimals(usdl).balanceOf(to);
        // uint256 afterBalanceCollateral = IERC20Decimals(collateral).balanceOf(to);
    }

    function _mintUSDLWExactUSDLNoChecks(address to, address collateral, uint256 amount, uint256 dexIndex) internal {
        address usdl = address(d.usdl());
        _getMoneyForTo(to, collateral, amount);
        uint256 beforeBalanceUSDL = IERC20Decimals(usdl).balanceOf(to);
        uint256 beforeBalanceCollateral = IERC20Decimals(collateral).balanceOf(to);
        IERC20Decimals(collateral).approve(usdl, type(uint256).max);
        // uint256 beforeTotalUsdl = d.pl().mintedPositionUsdlForThisWrapper();
        // 4th param is maxCollateralAmountRequired which is need to be set using callStatic, currently set uint256 max
        // calsstatic is not possible in solidity so
        d.usdl().depositTo(to, amount, dexIndex, type(uint256).max, IERC20Decimals(collateral));
        // uint256 afterTotalUsdl = d.pl().mintedPositionUsdlForThisWrapper();
        // uint256 afterBalanceUSDL = IERC20Decimals(usdl).balanceOf(to);
        // uint256 afterBalanceCollateral = IERC20Decimals(collateral).balanceOf(to);
        // assertEq(afterTotalUsdl - beforeTotalUsdl, afterBalanceUSDL);
        // assertEq(afterBalanceUSDL, beforeBalanceUSDL + amount);
        // assertTrue(afterBalanceCollateral < beforeBalanceCollateral);
    }

    function depositUSDC() public {
        address perpLemmaEth = 0x29b159aE784Accfa7Fb9c7ba1De272bad75f5674;
        address perpLemmaBtc = 0xe161C6c9F2fC74AC97300e6f00648284d83cBd19;

        vm.startPrank(d.admin());
        deal(d.getAddresses().USDC, d.admin(), 100000e18);

        IPerpLemma(perpLemmaEth).grantRole(USDC_TREASURY, d.admin());
        IPerpLemma(perpLemmaBtc).grantRole(USDC_TREASURY, d.admin());

        IERC20(d.getAddresses().USDC).approve(perpLemmaEth, type(uint256).max);
        IERC20(d.getAddresses().USDC).approve(perpLemmaBtc, type(uint256).max);

        IPerpLemma(perpLemmaEth).depositSettlementToken(5000e6);
        IPerpLemma(perpLemmaBtc).depositSettlementToken(5000e6);

        vm.stopPrank();
    }

    // Let's put some collateral
    function setUpForSwap() public {
        // Trying to mint USDL with WETH
        Minter m1 = new Minter(d);
        m1.mint(IERC20Decimals(address(d.weth())), 0, 1e18); // 1 ether
        // Trying to mint USDL with WBTC
        Minter m2 = new Minter(d);
        m2.mint(IERC20Decimals(address(d.wbtc())), 0, 4374840); // 0.4374840 WBTC
    }

    // for e.g if we want to swap weth -> wbtc
    // then tokenIn => weth AND tokenOut => wbtc
    function getMaxAmountInUsedForFuzzing(
        uint256 tokenInIndex,
        uint256 tokenOutIndex,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint256) {
        address perpLemmaIn = d.usdl().perpetualDEXWrappers(
            tokenInIndex,
            tokenIn
        );
        address perpLemmaOut = d.usdl().perpetualDEXWrappers(
            tokenOutIndex,
            tokenOut
        );
        uint256 tokenOutDeposited;
        if (IPerpLemma(perpLemmaOut).isUsdlCollateralTailAsset()) {
            tokenOutDeposited = d.wbtc().balanceOf(perpLemmaOut);
        } else {
            int256 tempTokenOutDeposited = IPerpVault(d.perpVault())
                .getBalanceByToken(perpLemmaOut, tokenOut);
            tempTokenOutDeposited = tempTokenOutDeposited < 0
                ? tempTokenOutDeposited * (-1)
                : tempTokenOutDeposited;
            tokenOutDeposited = uint256(tempTokenOutDeposited);
        }
        uint256 indexPriceOfTokenIn = IPerpLemma(perpLemmaIn).getIndexPrice();
        uint256 indexPriceOfTokenOut = IPerpLemma(perpLemmaOut).getIndexPrice();
        uint256 tokenOutDecimal = IERC20Decimals(address(d.wbtc())).decimals();
        tokenOutDeposited = (tokenOutDeposited * 1e18) / (10**tokenOutDecimal);
        uint256 totalUsdcInTermOfTokenOut = (uint256(tokenOutDeposited) *
            uint256(indexPriceOfTokenOut)) / 1e18;
        uint256 maxTokenInUsed = (totalUsdcInTermOfTokenOut * 1e18) /
            indexPriceOfTokenIn;
        return maxTokenInUsed;
    }

    function testSetupForSwap() public {
        depositUSDC();
        setUpForSwap();
    }

    function testFailPayable() public {
        TransferHelper.safeTransferETH(address(d.lemmaSwap()), 1e18);
    }

    function testTokenInIsUSDL() public noAsstesLeft {
        testSetupForSwap();
        deal(address(d.usdl()), address(this), 10e18);

        uint256 usdlInitialBalance = d.usdl().balanceOf(address(this));
        uint256 wethInitialBalance = d.weth().balanceOf(address(this));

        d.usdl().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.usdl());
        path[1] = address(d.weth());

        uint256 amountIn = 10e18;

        uint256[] memory amountsOut = d.lemmaSwap().swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        assertTrue(
            d.usdl().balanceOf(address(this)) == usdlInitialBalance - amountIn
        );
        assertTrue(
            d.weth().balanceOf(address(this)) ==
                wethInitialBalance + amountsOut[1]
        );
    }

    function testTokenOutIsUSDL() public noAsstesLeft {
        testSetupForSwap();
        deal(address(d.weth()), address(this), 1e13);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 usdlInitialBalance = d.usdl().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.usdl());

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
            d.usdl().balanceOf(address(this)) ==
                usdlInitialBalance + amountsOut[1]
        );
    }

    function testSwapExactTokensForTokens() public noAsstesLeft {
        testSetupForSwap();

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

    function testSwapExactETHForTokens() public payable noAsstesLeft {
        testSetupForSwap();

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256 amountIn = 1e13;

        uint256[] memory amountsOut = d.lemmaSwap().swapExactETHForTokens{
            value: amountIn
        }(0, path, address(this), block.timestamp);

        assertTrue(
            d.wbtc().balanceOf(address(this)) ==
                wbtcInitialBalance + amountsOut[1]
        );
    }

    function testSwapExactTokensForETH() public noAsstesLeft {
        testSetupForSwap();

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
        assertTrue(address(this).balance == ethInitialBalance + amountsOut[1]);
    }

    function testFuzzSwapExactTokensForTokens(uint256 amountIn) public {
        testSetupForSwap();

        uint256 maxTokenInUsed = getMaxAmountInUsedForFuzzing(
            0,
            0,
            address(d.weth()),
            address(d.wbtc())
        );
        vm.assume(amountIn > 1e6);
        vm.assume(amountIn < maxTokenInUsed);

        d.askForMoney(address(d.weth()), 10e18);

        uint256 wethInitialBalance = d.weth().balanceOf(address(this));
        uint256 wbtcInitialBalance = d.wbtc().balanceOf(address(this));

        d.weth().approve(address(d.lemmaSwap()), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(d.weth());
        path[1] = address(d.wbtc());

        uint256[] memory amountsOut = d.lemmaSwap().swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        // assertTrue(
        //     d.weth().balanceOf(address(this)) == wethInitialBalance - amountIn
        // );
        // assertTrue(
        //     d.wbtc().balanceOf(address(this)) ==
        //         wbtcInitialBalance + amountsOut[1]
        // );
    }

    enum StakeAsset {
        USDL,
        LemmaETH,
        LemmaBTC
    }

    // NOTE: Introduced as a trick to have functions with named arguments which makes the code more readable  
    struct StakeParams {
        StakeAsset asset;
        uint256 amount;
        bool isAdd;
        address recipient;
    }

    function _stake(StakeParams memory p) internal {
        require(p.amount > 0, "Need to stake > 0");
        if(p.asset == StakeAsset.USDL) {
            if(p.isAdd) {
                deal(address(d.usdl()), address(this), p.amount);
            }
            // uint256 amountUSDL = d.usdl().balanceOf(address(this));
            // require(amountUSDL > 0, "No USDL");
            d.usdl().approve(address(d.getAddresses().xusdl), p.amount);
            IXUSDL(d.getAddresses().xusdl).deposit(p.amount, p.recipient);
            // uint256 amountXUSDL = IXUSDL(d.getAddresses().xusdl).balanceOf(address(this));
            require(IXUSDL(d.getAddresses().xusdl).balanceOf(p.recipient) > 0, "No XUSDL");
            require(IXUSDL(d.getAddresses().xusdl).totalSupply() > 0, "No XUSDL Supply");
        }
        else if(p.asset == StakeAsset.LemmaETH) {
            if(p.isAdd) {
                deal(address(d.lemmaSynthEth()), address(this), p.amount);
            }
            // uint256 amountUSDL = d.usdl().balanceOf(address(this));
            // require(amountUSDL > 0, "No USDL");
            d.lemmaSynthEth().approve(address(d.getAddresses().xLemmaSynthEth), p.amount);
            IXUSDL(d.getAddresses().xLemmaSynthEth).deposit(p.amount, p.recipient);
            // uint256 amountXUSDL = IXUSDL(d.getAddresses().xusdl).balanceOf(address(this));
            require(IXUSDL(d.getAddresses().xLemmaSynthEth).balanceOf(p.recipient) > 0, "No XSynth");
            require(IXUSDL(d.getAddresses().xLemmaSynthEth).totalSupply() > 0, "No XSynth Supply");
        } 
        else if(p.asset == StakeAsset.LemmaBTC) {
            if(p.isAdd) {
                deal(address(d.lemmaSynthBtc()), address(this), p.amount);
            }
            // uint256 amountUSDL = d.usdl().balanceOf(address(this));
            // require(amountUSDL > 0, "No USDL");
            d.lemmaSynthBtc().approve(address(d.getAddresses().xLemmaSynthBtc), p.amount);
            IXUSDL(d.getAddresses().xLemmaSynthBtc).deposit(p.amount, p.recipient);
            // uint256 amountXUSDL = IXUSDL(d.getAddresses().xusdl).balanceOf(address(this));
            require(IXUSDL(d.getAddresses().xLemmaSynthBtc).balanceOf(p.recipient) > 0, "No XSynth");
            require(IXUSDL(d.getAddresses().xLemmaSynthBtc).totalSupply() > 0, "No XSynth Supply");
        } 
        else {
            require(false, "Unsupported Asset");
        }
    }

    function testDistributeFeesForEth() public noAsstesLeft {
        testSetupForSwap();

        d.askForMoney(address(d.weth()), 1e18);
        deal(address(d.usdc()), address(this), 10e6);

        d.weth().transfer(address(d.feesAccumulator()), 1e18);

        _stake(StakeParams({
            asset: StakeAsset.USDL,
            amount: 1 ether,
            isAdd: true,
            recipient: vm.addr(1)
        }));


        _stake(StakeParams({
            asset: StakeAsset.LemmaETH,
            amount: 0.2 ether,
            isAdd: true,
            recipient: vm.addr(2)
        }));

        uint256 balUsdlBefore = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthBefore = ILemmaSynth(d.getAddresses().LemmaSynthEth)
            .balanceOf(d.getAddresses().xLemmaSynthEth);
        d.feesAccumulator().distibuteFees(
            address(d.weth()),
            abi.encodeCall(
                MockSwapRouter.swap,
                (address(d.usdc()), address(d.feesAccumulator()), 10e6)
            )
        );
        uint256 balUsdlAfter = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthAfter = ILemmaSynth(d.getAddresses().LemmaSynthEth)
            .balanceOf(d.getAddresses().xLemmaSynthEth);
        assertGt(balUsdlAfter, balUsdlBefore);
        assertGt(balSynthAfter, balSynthBefore);
    }


    function testDistributeFeesForBtc() public noAsstesLeft {
        testSetupForSwap();
        d.askForMoney(address(d.wbtc()), 1e6);
        deal(address(d.usdc()), address(this), 10e6);

        // NOTE: Adding WBTC simulating the result of fees extracted from swaps 
        d.wbtc().transfer(address(d.feesAccumulator()), 1e6);

        // NOTE: Can't mint it because otherwise there would be 2 interactions withe PerpLemmaCommon.sol in the same TX and only LemmaSwap is allowed 
        // deal(address(d.weth()), address(this), 1 ether);
        // _mintUSDLWExactCollateralNoChecks(address(this), address(d.weth()), 1 ether);

        _stake(StakeParams({
            asset: StakeAsset.USDL,
            amount: 1 ether,
            isAdd: true,
            recipient: vm.addr(1)
        }));


        _stake(StakeParams({
            asset: StakeAsset.LemmaBTC,
            amount: 0.2 ether,
            isAdd: true,
            recipient: vm.addr(2)
        }));


        console.log("[testDistributeFeesForBtc()] xUSDL totalSupply = ", IXUSDL(d.getAddresses().xusdl).totalSupply());
        console.log("[testDistributeFeesForBtc()] LemmaSynthBtc totalSupply = ", IXUSDL(d.getAddresses().LemmaSynthBtc).totalSupply());

        uint256 balUsdlBefore = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthBTCBefore = ILemmaSynth(d.getAddresses().LemmaSynthBtc).balanceOf(d.getAddresses().xLemmaSynthBtc);
        uint256 balSynthETHBefore = ILemmaSynth(d.getAddresses().LemmaSynthEth).balanceOf(d.getAddresses().xLemmaSynthEth);
        d.feesAccumulator().distibuteFees(
            address(d.wbtc()),
            abi.encodeCall(
                MockSwapRouter.swap,
                (address(d.usdc()), address(d.feesAccumulator()), 10e6)
            )
        );
        uint256 balUsdlAfter = d.usdl().balanceOf(d.getAddresses().xusdl);
        uint256 balSynthBTCAfter = ILemmaSynth(d.getAddresses().LemmaSynthBtc).balanceOf(d.getAddresses().xLemmaSynthBtc);
        uint256 balSynthETHAfter = ILemmaSynth(d.getAddresses().LemmaSynthEth).balanceOf(d.getAddresses().xLemmaSynthEth);

        console.log("[testDistributeFeesForBtc()] balUsdlBefore = ", balUsdlBefore);
        console.log("[testDistributeFeesForBtc()] balUsdlAfter = ", balUsdlAfter);
        console.log("[testDistributeFeesForBtc()] balSynthBTCBefore = ", balSynthBTCBefore);
        console.log("[testDistributeFeesForBtc()] balSynthBTCAfter = ", balSynthBTCAfter);
        console.log("[testDistributeFeesForBtc()] balSynthETHBefore = ", balSynthETHBefore);
        console.log("[testDistributeFeesForBtc()] balSynthETHAfter = ", balSynthETHAfter);
        // NOTE: Something staken in xUSDL so rewards increased
        assertGt(balUsdlAfter, balUsdlBefore);
        assertEq(balSynthETHAfter, balSynthETHBefore);
        assertGt(balSynthBTCAfter, balSynthBTCBefore);
    }
}
