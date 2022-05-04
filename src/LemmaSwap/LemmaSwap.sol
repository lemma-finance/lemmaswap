pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
// import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
// import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {IUSDLSwapSubset} from "../interfaces/IUSDLSwapSubset.sol";
import {IWETH10} from "@weth10/interfaces/IWETH10.sol";

// import {IQuoter} from "./lib/interfaces/IQuoter.sol";
// import "../interfaces/IUSDLemma.sol";
// import "../interfaces/IPermit.sol";
import "../interfaces/ILemmaRouter.sol";
// import "forge-std/console.sol";

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

    // IQuoter quoter;


    IWETH10 public weth;

    constructor(
        // ILemmaRouter _lemmaRouter, 
        address _usdl, address _weth /*address _quoter*/) {
        owner = msg.sender;
        // lemmaRouter = _lemmaRouter; 
        usdl = IUSDLSwapSubset(_usdl);
        weth = IWETH10(_weth);
        // quoter = IQuoter(_quoter);

        // The standard is 0.1% 
        lemmaSwapFees = 1000;

        // usdl.approve(address(lemmaRouter), type(uint256).max);
    }

    // event Fallback(address, uint256);
    // event Receive(address, uint256);
    event NewOwner(address);
    event NewUSDL(address);
    event NewCollateralToDEXIndex(address, uint8);
    event NewLemmaSwapFees(uint256);

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

    fallback() external payable { 
        // emit Fallback((msg.sender), msg.value);
    }

    receive() external payable {
        // emit Receive((msg.sender), msg.value);
    }

    function setUSDL(address _usdl) external {
        require(_usdl != address(0), "! address");
        usdl = IUSDLSwapSubset(_usdl);
        emit NewUSDL(address(usdl));
    }

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "! address");
        owner = _owner;
        emit NewOwner(owner);
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
        emit NewCollateralToDEXIndex(collateral, dexIndex);
    }

    function setLemmaSwapFees(uint256 _fees) onlyOwner validFees(_fees) onlyOwner external {
        // TODO: Add emit event
        lemmaSwapFees = _fees;
        emit NewLemmaSwapFees(lemmaSwapFees);
    }

    function getProtocolFeesCoeffTokenIn() public view returns(uint256) {
        return (lemmaSwapFees / 2);
    }

    function getProtocolFeesCoeffTokenOut() public view returns(uint256) {
        return (lemmaSwapFees / 2);
    }

    function getProtocolFeesTokenIn(address token, uint256 amount) public view returns(uint256) {
        return amount * (lemmaSwapFees / 2) / 1e6;
    }

    function getProtocolFeesTokenOut(address token, uint256 amount) public view returns(uint256) {
        return amount * (lemmaSwapFees / 2) / 1e6;
    }

    function getAdjustedOutputAmount(address token, uint256 amount) public view returns(uint256) {
        uint256 dexIndex = convertCollateralToValidDexIndex(token);
        uint256 redeemFees = usdl.getFees(dexIndex, token, false);
        return amount * 1e6 / (1e6 - redeemFees);
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
        res[0] = swapWithExactInput(path[0], amountIn, path[1], amountOutMin, to);
        // res[0] = swapWithExactInput(
        //     sToken({
        //         token: IERC20(path[0]),
        //         amount: amountIn
        //     }), 
        //     sToken({
        //         token: IERC20(path[1]),
        //         amount: amountOutMin
        //     }),
        //     to
        //     );
        return res;
    }

    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L238
    // function swapTokensForExactTokens(
    //     uint amountOut,
    //     uint amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external returns (uint256[] memory amounts) {
    //     require(path.length == 2, "! Multi-hop swap not supported yet");
    //     uint256[] memory res = new uint256[](1);
    //     res[0] = swapWithExactOutput(
    //         sToken({
    //             token: IERC20(path[0]),
    //             amount: amountInMax
    //         }), 
    //         sToken({
    //             token: IERC20(path[1]),
    //             amount: amountOut
    //         }),
    //         to
    //         );
    //     return res;
    // }

    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L252
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts) {
            uint256 amountIn = msg.value;
            // console.log("[swapExactETHForTokens] msg.value = ", msg.value);
            TransferHelper.safeTransferETH(address(weth), amountIn);
            // weth.deposit{value: amountIn}();
            // console.log("[swapExactETHForTokens] After Deposit Balance = ", weth.balanceOf(address(this)));
            require(path.length == 1, "! Multi-hop swap not supported yet");
            uint256[] memory res = new uint256[](1);
            res[0] = _swapWithExactInput(address(weth), amountIn, path[0], amountOutMin, address(this), to);
            return res;
        }

    // function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    //     external 
    //     returns (uint256[] memory amounts) {
    //         require(path.length == 1, "! Multi-hop swap not supported yet");
    //         uint256[] memory res = new uint256[](1);
    //         res[0] = swapWithExactOutput(
    //             sToken({
    //                 token: IERC20(path[0]),
    //                 amount: amountInMax
    //             }), 
    //             sToken({
    //                 token: weth,
    //                 amount: amountOut
    //             }),
    //             address(this)
    //             );
    //         require(weth.balanceOf(address(this)) == amountOut, "! T111");
    //         // console.log("[swapTokensForExactETH] WETH Balance = ", weth.balanceOf(address(this)));
    //         weth.withdraw(amountOut);
    //         TransferHelper.safeTransferETH(to, amountOut);
    //         return res;
    //     }

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts) {
            require(path.length == 1, "! Multi-hop swap not supported yet");
            uint256[] memory res = new uint256[](1);
            res[0] = swapWithExactInput(path[0], amountIn, address(weth), amountOutMin, address(this));
            uint256 wethAmount = weth.balanceOf(address(this));
            require(wethAmount > amountOutMin, "! Amount Out Min");
            weth.withdraw(wethAmount);
            TransferHelper.safeTransferETH(to, wethAmount);
            return res;
        }

    // function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
    //     external
    //     payable
    //     returns (uint256[] memory amounts) {
    //         require(path.length == 1, "! Multi-hop swap not supported yet");
    //         uint256 amountIn = getAmountsIn(
    //         sToken({
    //             token: weth,
    //             amount: 0
    //         }), 
    //         sToken({
    //             token: IERC20(path[0]),
    //             amount: amountOut
    //         }));
    //         require(amountIn > 0, "No corresponding input amount");
    //         // console.log("[_swapWithExactOutput()] amountIn = ", amountIn);
    //         require(msg.value > amountIn, "! not enough ETH");
    //         TransferHelper.safeTransferETH(address(weth), amountIn);
    //         TransferHelper.safeTransferETH(msg.sender, msg.value - amountIn);
    //         uint256[] memory res = new uint256[](1);
    //         res[0] = _swapWithExactInput(
    //             sToken({
    //                 token: weth,
    //                 amount: amountIn
    //             }), 
    //             sToken({
    //                 token: IERC20(path[0]),
    //                 amount: 0
    //             }), address(this), to);
    //         return res;
    //     }






    // function getAmountsIn(sToken memory tokenIn, sToken memory tokenOut) public returns(uint256) {
    //     console.log("[getAmountsIn()] tokenOut.amount = ", tokenOut.amount);
    //     uint256 totalCollateralOutRequired = tokenOut.amount * 1e6 / (1e6 - getProtocolFeesCoeffTokenOut());
    //     // uint256 totalCollateralOutRequired = tokenOut.amount + getProtocolFeesTokenOut(tokenOut);
    //     console.log("[getAmountsIn()] totalCollateralOutRequired = ", totalCollateralOutRequired);
    //     uint256 totalUSDLRequired = quoter.Collateral2USDL(address(tokenOut.token), totalCollateralOutRequired);
    //     // uint256 totalUSDLRequired = usdl.Collateral2USDL(address(tokenOut.token), totalCollateralOutRequired);
    //     console.log("[getAmountsIn()] totalUSDLRequired = ", totalUSDLRequired);
    //     uint256 totalCollateralInRequired = quoter.USDL2Collateral(address(tokenIn.token), totalUSDLRequired);
    //     // uint256 totalCollateralInRequired = usdl.USDL2Collateral(address(tokenIn.token), totalUSDLRequired);
    //     console.log("[getAmountsIn()] totalCollateralInRequired = ",totalCollateralInRequired);
    //     uint256 res = totalCollateralInRequired * 1e6 / (1e6 - getProtocolFeesCoeffTokenIn());
    //     // uint256 res = totalCollateralInRequired + getProtocolFeesTokenIn(sToken({token: tokenIn.token, amount: totalCollateralInRequired}));
    //     console.log("[getAmountsIn()] res = ", res);
    //     return res;
    // }


    // function getAmountsOut(sToken memory tokenIn, sToken memory tokenOut) public returns(uint256) {
    //     console.log("[getAmountsOut()] tokenIn.amount = ", tokenIn.amount);
    //     uint256 netCollateralInAmount = tokenIn.amount - getProtocolFeesTokenIn(tokenIn);
    //     console.log("[getAmountsOut()] netCollateralInAmount = ", netCollateralInAmount);
    //     uint256 netUSDLAmount = quoter.Collateral2USDL(address(tokenIn.token), netCollateralInAmount);
    //     // uint256 netUSDLAmount = usdl.Collateral2USDL(address(tokenIn.token), netCollateralInAmount);
    //     console.log("[getAmountsOut()] netUSDLAmount = ", netUSDLAmount);
    //     uint256 totalCollateralOutAmount = quoter.USDL2Collateral(address(tokenOut.token), netUSDLAmount);
    //     // uint256 totalCollateralOutAmount = usdl.USDL2Collateral(address(tokenOut.token), netUSDLAmount);
    //     console.log("[getAmountsOut()] totalCollateralOutAmount = ", totalCollateralOutAmount);
    //     uint256 res = totalCollateralOutAmount - getProtocolFeesTokenOut(sToken({token: tokenOut.token, amount: totalCollateralOutAmount}));
    //     console.log("[getAmountsOut()] res = ", res);
    //     return res;
    // }


    function swapWithExactInputAndOutput(
        address tokenIn, 
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut,
        address to
    ) public returns (uint256) {

        // require(collateralToDexIndex[address(tokenIn.token)] != address(0), "! collateral tokenIn");
        // require(collateralToDexIndex[address(tokenOut.token)] != address(0), "! collateral tokenOut");

        require(amountIn > 0, "! tokenIn amount");
        require(amountOut > 0, "! tokenOut amount");

        // console.log("[LemmaSwap swapWithExactInputAndOutput()] TokenIn Amount ", tokenIn.amount);
        // console.log("[LemmaSwap swapWithExactInputAndOutput()] collateralToDexIndex[address(tokenIn.token)] ", convertCollateralToValidDexIndex(address(tokenIn.token)));

        TransferHelper.safeTransferFrom(
            address(tokenIn),
            msg.sender,
            address(this),
            amountIn
        );

        // console.log("[LemmaSwap] Balance TokenIn Before = ", tokenIn.token.balanceOf(address(this)));

        uint256 protocolFeesIn = getProtocolFeesTokenIn(tokenIn, amountIn);
        TransferHelper.safeTransfer(
            tokenIn,
            usdl.lemmaTreasury(),
            getProtocolFeesTokenIn(tokenIn, amountIn)
        );
        
        // console.log("[LemmaSwap] protocolFeesIn = ", protocolFeesIn);
        
        // console.log("[LemmaSwap] LemmaTreasury = ", usdl.lemmaTreasury());

        // console.log("[LemmaSwap] Balance TokenIn After = ", tokenIn.token.balanceOf(address(this)));

        amountIn = IERC20(tokenIn).balanceOf(address(this));

        if (IERC20(tokenIn).allowance(address(this), address(usdl)) < type(uint256).max) {
            IERC20(tokenIn).approve(address(usdl), type(uint256).max);
        }

        usdl.depositToWExactCollateral(
            address(this),
            amountIn,
            convertCollateralToValidDexIndex(tokenIn),
            0,
            IERC20(tokenIn)
        );
        // Need to take into account there is a 1% fee in redeeming 
        // uint256 expectedOutput = tokenOut.amount;
        // tokenOut.amount = getAdjustedOutputAmount(tokenOut);

        uint256 protocolFeesOut = getProtocolFeesTokenOut(tokenOut, amountOut);
        usdl.withdrawToWExactCollateral(
            address(this),
            amountOut + protocolFeesOut,
            convertCollateralToValidDexIndex(tokenOut),
            type(uint256).max,
            IERC20(tokenOut)
        );

        TransferHelper.safeTransfer(
            tokenOut,
            usdl.lemmaTreasury(),
            getProtocolFeesTokenOut(tokenOut, amountOut)
        );
        
        // console.log("[LemmaSwap] protocolFeesOut = ", protocolFeesOut);

        uint256 netCollateralToGetBack = IERC20(tokenOut).balanceOf(address(this));

        TransferHelper.safeTransfer(
            tokenOut,
            msg.sender,
            netCollateralToGetBack
        );

        //_returnAllTokens(tokenIn.token);
        _returnAllTokens(usdl, to);

        return IERC20(tokenOut).balanceOf(address(this));
    }


    function swapWithExactInput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut,
        address to
    ) public returns (uint256) {

        return _swapWithExactInput(tokenIn, amountIn, tokenOut, amountOut, msg.sender, to);
    }


    function _swapWithExactInput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut, 
        uint256 amountOut,
        address from,
        address to
    ) internal returns (uint256) {

        // require(collateralToDexIndex[address(tokenIn.token)] != address(0), "! collateral tokenIn");
        // require(collateralToDexIndex[address(tokenOut.token)] != address(0), "! collateral tokenOut");

        require(amountIn > 0, "! tokenIn amount");

        // console.log("[LemmaSwap swapWithExactInput()] TokenIn Amount ", tokenIn.amount);
        // console.log("[LemmaSwap swapWithExactInput()] collateralToDexIndex[address(tokenIn.token)] ", convertCollateralToValidDexIndex(address(tokenIn.token)));

        if (from != address(this)) {
            TransferHelper.safeTransferFrom(
                tokenIn,
                from,
                address(this),
                amountIn
            );
        }

        // console.log("[LemmaSwap] Balance TokenIn Before = ", tokenIn.token.balanceOf(address(this)));

        uint256 protocolFeesIn = getProtocolFeesTokenIn(tokenIn, amountIn);
        TransferHelper.safeTransfer(
            tokenIn,
            usdl.lemmaTreasury(),
            getProtocolFeesTokenIn(tokenIn, amountIn)
        );
        
        // console.log("[LemmaSwap] protocolFeesIn = ", protocolFeesIn);
        
        // console.log("[LemmaSwap] LemmaTreasury = ", usdl.lemmaTreasury());

        // console.log("[LemmaSwap] Balance TokenIn After = ", tokenIn.token.balanceOf(address(this)));

        // tokenIn.amount = tokenIn.token.balanceOf(address(this));


        if (IERC20(tokenIn).allowance(address(this), address(usdl)) < type(uint256).max) {
            IERC20(tokenIn).approve(address(usdl), type(uint256).max);
        }

        usdl.depositToWExactCollateral(
            address(this),
            IERC20(tokenIn).balanceOf(address(this)),
            convertCollateralToValidDexIndex(tokenIn),
            0,
            IERC20(tokenIn)
        );
        // Need to take into account there is a 1% fee in redeeming 
        // uint256 expectedOutput = tokenOut.amount;
        // tokenOut.amount = getAdjustedOutputAmount(tokenOut);

        uint256 usdlAmount = usdl.balanceOf(address(this));

        usdl.withdrawTo(
            address(this),
            usdlAmount,
            convertCollateralToValidDexIndex(tokenOut),
            amountOut,
            IERC20(tokenOut)
        );

        // tokenOut.amount = tokenOut.token.balanceOf(address(this));

        // console.log("[_swapWithExactInput()] TokenOut Amount = ", tokenOut.token.balanceOf(address(this)));

        uint256 protocolFeesOut = getProtocolFeesTokenOut(tokenOut, IERC20(tokenOut).balanceOf(address(this)));

        TransferHelper.safeTransfer(
            tokenOut,
            usdl.lemmaTreasury(),
            protocolFeesOut
        );
        
        // console.log("[LemmaSwap] protocolFeesOut = ", protocolFeesOut);

        uint256 netCollateralToGetBack = IERC20(tokenOut).balanceOf(address(this));

        // console.log("netCollateralToGetBack = ", netCollateralToGetBack);

        require(netCollateralToGetBack >= amountOut, "! netCollateralToGetBack");

        TransferHelper.safeTransfer(
            tokenOut,
            to,
            netCollateralToGetBack
        );

        //_returnAllTokens(tokenIn.token);
        _returnAllTokens(usdl, to);

        return netCollateralToGetBack;
    }

    // function swapWithExactOutput(
    //     sToken memory tokenIn,
    //     sToken memory tokenOut, 
    //     address to
    // ) public returns (uint256) {
    //     return _swapWithExactOutput(tokenIn, tokenOut, msg.sender, to);
    // }

    // function _swapWithExactOutput(
    //     sToken memory tokenIn,
    //     sToken memory tokenOut, 
    //     address from,
    //     address to
    // ) internal returns (uint256) {
    //     uint256 amountIn = getAmountsIn(tokenIn, tokenOut);
    //     // console.log("[_swapWithExactOutput()] amountIn = ", amountIn);
    //     tokenIn.amount = amountIn;
    //     require(tokenIn.amount > 0, "No corresponding input amount");
    //     return _swapWithExactInput(tokenIn, tokenOut, from, to);
    // }



}

