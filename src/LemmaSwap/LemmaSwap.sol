pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
// import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
// import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {IUSDLSwapSubset} from "../interfaces/IUSDLSwapSubset.sol";
import {IWETH10} from "@weth10/interfaces/IWETH10.sol";
// import "../interfaces/IUSDLemma.sol";
import "../interfaces/IPermit.sol";
import "../interfaces/ILemmaRouter.sol";
import "forge-std/console.sol";

interface IERC20Decimal is IERC20 {
    function decimals() external view returns (uint256);
}

contract LemmaSwap {
    address public owner;
    ILemmaRouter public lemmaRouter;
    mapping (address => uint8) public collateralToDexIndex; 

    IUSDLSwapSubset public usdl;

    // Fees in 1e6 format: 1e6 is 100% 
    uint256 public lemmaSwapFees; 


    IWETH10 public weth;

    constructor(
        // ILemmaRouter _lemmaRouter, 
        address _usdl, address _weth) {
        owner = msg.sender;
        // lemmaRouter = _lemmaRouter; 
        usdl = IUSDLSwapSubset(_usdl);
        weth = IWETH10(_weth);

        // The standard is 0.1% 
        lemmaSwapFees = 1000;

        // usdl.approve(address(lemmaRouter), type(uint256).max);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier validCollateral(address collateral) {
        require(collateral != address(0), "!collateral");
        _;
    }

    modifier validFees(uint256 fees) {
        require(fees <= 1e6, "!fees");
        _;
    }

    function _returnAllTokens(IERC20 token, address to) internal {
        if (token.balanceOf(address(this)) > 0) {
            TransferHelper.safeTransfer(
                address(token),
                to,
                token.balanceOf(address(this))
            );
        }
    }

    function setCollateralToDexIndex(address collateral, uint8 dexIndex) onlyOwner validCollateral(collateral) external {
        // TODO: Add emit event
        collateralToDexIndex[collateral] = dexIndex + 1;
    }

    function setLemmaSwapFees(uint256 _fees) onlyOwner validFees(_fees) external {
        // TODO: Add emit event
        lemmaSwapFees = _fees;
    }

    function getProtocolFeesCoeffTokenIn() public view returns(uint256) {
        return (lemmaSwapFees / 2);
    }

    function getProtocolFeesCoeffTokenOut() public view returns(uint256) {
        return (lemmaSwapFees / 2);
    }

    function getProtocolFeesTokenIn(sToken memory token) public view returns(uint256) {
        return token.amount * (lemmaSwapFees / 2) / 1e6;
    }

    function getProtocolFeesTokenOut(sToken memory token) public view returns(uint256) {
        return token.amount * (lemmaSwapFees / 2) / 1e6;
    }

    function getAdjustedOutputAmount(sToken memory tokenOut) public view returns(uint256) {
        uint256 dexIndex = convertCollateralToValidDexIndex(address(tokenOut.token));
        uint256 redeemFees = usdl.getFees(dexIndex, address(tokenOut.token), false);
        return tokenOut.amount * 1e6 / (1e6 - redeemFees);
    }

    function getMaxOutput(address token) public view returns(int256) {
        if(collateralToDexIndex[token] == 0) {
            // Collateral not supported
            return 0;
        }
        return usdl.getTotalPosition(
            convertCollateralToValidDexIndex(token), 
            token
            );
    }

    function convertCollateralToValidDexIndex(address collateral) internal view returns(uint256) {
        require(collateral != address(0), "!collateral");
        require(collateralToDexIndex[collateral] != 0, "Collateral not supported");
        return collateralToDexIndex[collateral] - 1;
    }

    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L224
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length == 2, "! Multi-hop swap not supported yet");
        uint256[] memory res = new uint256[](1);
        res[0] = swapWithExactInput(
            sToken({
                token: IERC20(path[0]),
                amount: amountIn
            }), 
            sToken({
                token: IERC20(path[1]),
                amount: amountOutMin
            }),
            to
            );
        return res;
    }

    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L238
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length == 2, "! Multi-hop swap not supported yet");
        uint256[] memory res = new uint256[](1);
        res[0] = swapWithExactOutput(
            sToken({
                token: IERC20(path[0]),
                amount: amountInMax
            }), 
            sToken({
                token: IERC20(path[1]),
                amount: amountOut
            }),
            to
            );
        return res;
    }

    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L252
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts) {
            uint256 amountIn = msg.value;
            console.log("[swapExactETHForTokens] msg.value = ", msg.value);
            weth.deposit{value: amountIn}();
            console.log("[swapExactETHForTokens] After Deposit Balance = ", weth.balanceOf(address(this)));
            require(path.length == 1, "! Multi-hop swap not supported yet");
            uint256[] memory res = new uint256[](1);
            res[0] = _swapWithExactInput(
                sToken({
                    token: weth,
                    amount: amountIn
                }), 
                sToken({
                    token: IERC20(path[0]),
                    amount: amountOutMin
                }),
                address(this),
                to
                );
            return res;
        }

    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts) {

        }

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts) {

        }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts) {

        }






    function getAmountsIn(sToken memory tokenIn, sToken memory tokenOut) public view returns(uint256) {
        console.log("[getAmountsIn()] tokenOut.amount = ", tokenOut.amount);
        uint256 totalCollateralOutRequired = tokenOut.amount * 1e6 / (1e6 - getProtocolFeesCoeffTokenOut());
        // uint256 totalCollateralOutRequired = tokenOut.amount + getProtocolFeesTokenOut(tokenOut);
        console.log("[getAmountsIn()] totalCollateralOutRequired = ", totalCollateralOutRequired);
        uint256 totalUSDLRequired = usdl.Collateral2USDL(address(tokenOut.token), totalCollateralOutRequired);
        console.log("[getAmountsIn()] totalUSDLRequired = ", totalUSDLRequired);
        uint256 totalCollateralInRequired = usdl.USDL2Collateral(address(tokenIn.token), totalUSDLRequired);
        console.log("[getAmountsIn()] totalCollateralInRequired = ",totalCollateralInRequired);
        uint256 res = totalCollateralInRequired * 1e6 / (1e6 - getProtocolFeesCoeffTokenIn());
        // uint256 res = totalCollateralInRequired + getProtocolFeesTokenIn(sToken({token: tokenIn.token, amount: totalCollateralInRequired}));
        console.log("[getAmountsIn()] res = ", res);
        return res;
    }


    function getAmountsOut(sToken memory tokenIn, sToken memory tokenOut) public view returns(uint256) {
        console.log("[getAmountsOut()] tokenIn.amount = ", tokenIn.amount);
        uint256 netCollateralInAmount = tokenIn.amount - getProtocolFeesTokenIn(tokenIn);
        console.log("[getAmountsOut()] netCollateralInAmount = ", netCollateralInAmount);
        uint256 netUSDLAmount = usdl.Collateral2USDL(address(tokenIn.token), netCollateralInAmount);
        console.log("[getAmountsOut()] netUSDLAmount = ", netUSDLAmount);
        uint256 totalCollateralOutAmount = usdl.USDL2Collateral(address(tokenOut.token), netUSDLAmount);
        console.log("[getAmountsOut()] totalCollateralOutAmount = ", totalCollateralOutAmount);
        uint256 res = totalCollateralOutAmount - getProtocolFeesTokenOut(sToken({token: tokenOut.token, amount: totalCollateralOutAmount}));
        console.log("[getAmountsOut()] res = ", res);
        return res;
    }


    function swapWithExactInputAndOutput(
        sToken memory tokenIn,
        sToken memory tokenOut,
        address to
    ) public returns (uint256) {

        // require(collateralToDexIndex[address(tokenIn.token)] != address(0), "! collateral tokenIn");
        // require(collateralToDexIndex[address(tokenOut.token)] != address(0), "! collateral tokenOut");

        require(tokenIn.amount > 0, "! tokenIn amount");
        require(tokenOut.amount > 0, "! tokenOut amount");

        console.log("[LemmaSwap swapWithExactInputAndOutput()] TokenIn Amount ", tokenIn.amount);
        console.log("[LemmaSwap swapWithExactInputAndOutput()] collateralToDexIndex[address(tokenIn.token)] ", convertCollateralToValidDexIndex(address(tokenIn.token)));

        TransferHelper.safeTransferFrom(
            address(tokenIn.token),
            msg.sender,
            address(this),
            tokenIn.amount
        );

        console.log("[LemmaSwap] Balance TokenIn Before = ", tokenIn.token.balanceOf(address(this)));

        uint256 protocolFeesIn = getProtocolFeesTokenIn(tokenIn);
        TransferHelper.safeTransfer(
            address(tokenIn.token),
            usdl.lemmaTreasury(),
            getProtocolFeesTokenIn(tokenIn)
        );
        
        console.log("[LemmaSwap] protocolFeesIn = ", protocolFeesIn);
        
        // console.log("[LemmaSwap] LemmaTreasury = ", usdl.lemmaTreasury());

        console.log("[LemmaSwap] Balance TokenIn After = ", tokenIn.token.balanceOf(address(this)));

        tokenIn.amount = tokenIn.token.balanceOf(address(this));

        if (tokenIn.token.allowance(address(this), address(usdl)) < type(uint256).max) {
            tokenIn.token.approve(address(usdl), type(uint256).max);
        }

        usdl.depositToWExactCollateral(
            address(this),
            tokenIn.amount,
            convertCollateralToValidDexIndex(address(tokenIn.token)),
            0,
            tokenIn.token
        );
        // Need to take into account there is a 1% fee in redeeming 
        // uint256 expectedOutput = tokenOut.amount;
        // tokenOut.amount = getAdjustedOutputAmount(tokenOut);

        uint256 protocolFeesOut = getProtocolFeesTokenOut(tokenOut);
        usdl.withdrawToWExactCollateral(
            address(this),
            tokenOut.amount + protocolFeesOut,
            convertCollateralToValidDexIndex(address(tokenOut.token)),
            type(uint256).max,
            tokenOut.token
        );

        TransferHelper.safeTransfer(
            address(tokenOut.token),
            usdl.lemmaTreasury(),
            getProtocolFeesTokenOut(tokenOut)
        );
        
        console.log("[LemmaSwap] protocolFeesOut = ", protocolFeesOut);

        uint256 netCollateralToGetBack = tokenOut.token.balanceOf(address(this));

        TransferHelper.safeTransfer(
            address(tokenOut.token),
            msg.sender,
            netCollateralToGetBack
        );

        //_returnAllTokens(tokenIn.token);
        _returnAllTokens(usdl, to);

        return tokenOut.token.balanceOf(address(this));
    }


    function swapWithExactInput(
        sToken memory tokenIn,
        sToken memory tokenOut,
        address to
    ) public returns (uint256) {

        return _swapWithExactInput(tokenIn, tokenOut, msg.sender, to);
    }


    function _swapWithExactInput(
        sToken memory tokenIn,
        sToken memory tokenOut,
        address from,
        address to
    ) internal returns (uint256) {

        // require(collateralToDexIndex[address(tokenIn.token)] != address(0), "! collateral tokenIn");
        // require(collateralToDexIndex[address(tokenOut.token)] != address(0), "! collateral tokenOut");

        require(tokenIn.amount > 0, "! tokenIn amount");

        console.log("[LemmaSwap swapWithExactInput()] TokenIn Amount ", tokenIn.amount);
        console.log("[LemmaSwap swapWithExactInput()] collateralToDexIndex[address(tokenIn.token)] ", convertCollateralToValidDexIndex(address(tokenIn.token)));

        TransferHelper.safeTransferFrom(
            address(tokenIn.token),
            from,
            address(this),
            tokenIn.amount
        );

        console.log("[LemmaSwap] Balance TokenIn Before = ", tokenIn.token.balanceOf(address(this)));

        uint256 protocolFeesIn = getProtocolFeesTokenIn(tokenIn);
        TransferHelper.safeTransfer(
            address(tokenIn.token),
            usdl.lemmaTreasury(),
            getProtocolFeesTokenIn(tokenIn)
        );
        
        console.log("[LemmaSwap] protocolFeesIn = ", protocolFeesIn);
        
        // console.log("[LemmaSwap] LemmaTreasury = ", usdl.lemmaTreasury());

        console.log("[LemmaSwap] Balance TokenIn After = ", tokenIn.token.balanceOf(address(this)));

        // tokenIn.amount = tokenIn.token.balanceOf(address(this));


        if (tokenIn.token.allowance(address(this), address(usdl)) < type(uint256).max) {
            tokenIn.token.approve(address(usdl), type(uint256).max);
        }

        usdl.depositToWExactCollateral(
            address(this),
            tokenIn.token.balanceOf(address(this)),
            convertCollateralToValidDexIndex(address(tokenIn.token)),
            0,
            tokenIn.token
        );
        // Need to take into account there is a 1% fee in redeeming 
        // uint256 expectedOutput = tokenOut.amount;
        // tokenOut.amount = getAdjustedOutputAmount(tokenOut);

        uint256 usdlAmount = usdl.balanceOf(address(this));

        usdl.withdrawTo(
            address(this),
            usdlAmount,
            convertCollateralToValidDexIndex(address(tokenOut.token)),
            tokenOut.amount,
            tokenOut.token
        );

        // tokenOut.amount = tokenOut.token.balanceOf(address(this));

        console.log("T222 Amount = ", tokenOut.token.balanceOf(address(this)));

        uint256 protocolFeesOut = getProtocolFeesTokenOut(sToken({
            token: tokenOut.token,
            amount: tokenOut.token.balanceOf(address(this))
        }));

        TransferHelper.safeTransfer(
            address(tokenOut.token),
            usdl.lemmaTreasury(),
            protocolFeesOut
        );
        
        console.log("[LemmaSwap] protocolFeesOut = ", protocolFeesOut);

        uint256 netCollateralToGetBack = tokenOut.token.balanceOf(address(this));

        console.log("netCollateralToGetBack = ", netCollateralToGetBack);

        require(netCollateralToGetBack >= tokenOut.amount, "! netCollateralToGetBack");

        TransferHelper.safeTransfer(
            address(tokenOut.token),
            to,
            netCollateralToGetBack
        );

        //_returnAllTokens(tokenIn.token);
        _returnAllTokens(usdl, to);

        return netCollateralToGetBack;
    }


    function swapWithExactOutput(
        sToken memory tokenIn,
        sToken memory tokenOut, 
        address to
    ) public returns (uint256) {
        uint256 amountIn = getAmountsIn(tokenIn, tokenOut);
        console.log("T11111 amountIn = ", amountIn);
        tokenIn.amount = amountIn;
        require(tokenIn.amount > 0, "No corresponding input amount");
        return swapWithExactInput(tokenIn, tokenOut, to);
    }



}

