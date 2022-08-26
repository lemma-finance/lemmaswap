pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUSDLSwapSubset} from "../interfaces/IUSDLSwapSubset.sol";
import {IWETH10} from "@weth10/interfaces/IWETH10.sol";
import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {ILemmaRouter} from "../interfaces/ILemmaRouter.sol";
import "../interfaces/IERC20Decimals.sol";
import "forge-std/Test.sol";

contract LemmaSwap {
    address public owner;
    address public feesAccumulator;

    ILemmaRouter public lemmaRouter;
    IWETH10 public weth;
    IUSDLSwapSubset public usdl;

    // Fees in 1e6 format: 1e6 is 100%
    uint256 public lemmaSwapFees;
    
    // Assumption: there is 1:1 collateral token to dexIndex relationship
    mapping(address => uint8) public collateralToDexIndex;

    constructor(address _usdl, address _weth, address _feesAccumulator) {
        owner = msg.sender;
        usdl = IUSDLSwapSubset(_usdl);
        weth = IWETH10(_weth);
        feesAccumulator = _feesAccumulator;

        // Initial fee is 0.1%
        lemmaSwapFees = 1000;
    }

    event NewOwner(address);
    event NewUSDL(address);
    event NewWETH(address);
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

    fallback() external payable {}

    receive() external payable {}


    function setWETH(address _weth) external onlyOwner {
        require(_weth != address(0), "! address");
        weth = IWETH10(_weth);
        emit NewWETH(address(weth));
    }

    function setUSDL(address _usdl) external onlyOwner {
        require(_usdl != address(0), "! address");
        usdl = IUSDLSwapSubset(_usdl);
        emit NewUSDL(address(usdl));
    }

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "! address");
        owner = _owner;
        emit NewOwner(owner);
    }


    /**
        @notice Updates the Collateral --> dexIndex association
        @dev The dexIndex is a low level detail that we won't to hide from the UX related methods 
     */
    function setCollateralToDexIndex(address collateral, uint8 dexIndex)
        external
        onlyOwner
        validCollateral(collateral)
    {
        collateralToDexIndex[collateral] = dexIndex + 1;
        emit NewCollateralToDEXIndex(collateral, dexIndex);
    }

    /**
        @notice Update LemmaSwap fees in 1e6 format
        @dev The dexIndex is a low level detail that we won't to hide from the UX related methods 
     */
    function setLemmaSwapFees(uint256 _fees)
        external
        onlyOwner
        validFees(_fees)
        onlyOwner
    {
        lemmaSwapFees = _fees;
        emit NewLemmaSwapFees(lemmaSwapFees);
    }

    /**
        @notice LemmaSwap fees to be taken on input token
        @dev The fees are in 1e6 format
     */
    function getProtocolFeesCoeffTokenIn() public view returns (uint256) {
        return (lemmaSwapFees / 2);
    }

    /**
        @notice LemmaSwap fees to be taken on output token
        @dev The fees are in 1e6 format
     */
    function getProtocolFeesCoeffTokenOut() public view returns (uint256) {
        return (lemmaSwapFees / 2);
    }

    /**
        @notice Computes the total amount of fees on input token
     */
    function getProtocolFeesTokenIn(address token, uint256 amount)
        public
        view
        returns (uint256)
    {
        return (amount * getProtocolFeesCoeffTokenIn()) / 1e6;
    }

    /**
        @notice Computes the total amount of fees on output token
     */
    function getProtocolFeesTokenOut(address token, uint256 amount)
        public
        view
        returns (uint256)
    {
        return (amount * getProtocolFeesCoeffTokenOut()) / 1e6;
    }

    function getAdjustedOutputAmount(address token, uint256 amount)
        external
        view
        returns (uint256)
    {
        uint256 dexIndex = _convertCollateralToValidDexIndex(token);
        uint256 redeemFees = usdl.getFees(dexIndex, token, false);
        return (amount * 1e6) / (1e6 - redeemFees);
    }

    /**
        @notice Returns the max possible output for a given token
        @dev The max possible output corresponds to the max amount of collateral that is possible to withdraw from the underlying protocol 
     */
    function getMaxOutput(address token) external view returns (int256) {
        if (collateralToDexIndex[token] == 0) {
            // Collateral not supported
            return 0;
        }
        return
            usdl.getTotalPosition(
                _convertCollateralToValidDexIndex(token),
                token
            );
    }

    /**
        @notice     Swaps an exact amount of input tokens for an amount of output tokens that is computed as a function of the input and price 
        @param      amountIn        The amount of the input token 
        @param      amountOutMin    The minimum amount of output token
        @param      path            An array of 2 addresses: input token and output token
        @param      to              Address receiving the output tokens
        @param      deadline        Currently ignored
        @dev The msg.sender, prior to calling this function, has to approve LemmaSwap for at least the amountIn 
        @dev https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L224
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length == 2, "! Multi-hop swap not supported yet");
        uint256[] memory res = new uint256[](1);
        res[0] = _swapWithExactInput(
            path[0],
            amountIn,
            path[1],
            amountOutMin,
            msg.sender,
            to
        );
        return res;
    }

    /**
        @notice     Swaps an exact amount of ETH for an amount of output tokens that is computed as a function of the input and price 
        @param      amountOutMin    The minimum amount of output token
        @param      path            An array of 2 addresses: input token and output token
        @param      to              Address receiving the output tokens
        @param      deadline        Currently ignored
        @dev The amountIn is the amount of ETH the msg.sender sends to this function when calling it 
        @dev https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L252
    */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        uint256 amountIn = msg.value;
        // console.log("[swapExactETHForTokens] msg.value = ", msg.value);
        TransferHelper.safeTransferETH(address(weth), amountIn);
        // weth.deposit{value: amountIn}();
        // console.log("[swapExactETHForTokens] After Deposit Balance = ", weth.balanceOf(address(this)));
        // require(path.length == 1, "! Multi-hop swap not supported yet");
        uint256[] memory res = new uint256[](1);
        res[0] = _swapWithExactInput(
            address(weth),
            amountIn,
            path[0],
            amountOutMin,
            address(this),
            to
        );
        return res;
    }

     /**
        @notice     Swaps an exact amount of input tokens for an amount of ETH that is computed as a function of the input and price 
        @param      amountIn        The amount of the input token
        @param      amountOutMin    The minimum amount of ETH to get
        @param      path            An array of 1 address: the input token 
        @param      to              Address receiving the output tokens
        @param      deadline        Currently ignored
        @dev The msg.sender, prior to calling this function, has to approve LemmaSwap for at least the amountIn 
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length == 1, "! Multi-hop swap not supported yet");
        uint256[] memory res = new uint256[](1);
        res[0] = _swapWithExactInput(
            path[0],
            amountIn,
            address(weth),
            amountOutMin,
            msg.sender,
            address(this)
        );
        uint256 wethAmount = weth.balanceOf(address(this));
        require(wethAmount > amountOutMin, "! Amount Out Min");
        weth.withdraw(wethAmount);
        TransferHelper.safeTransferETH(to, wethAmount);
        return res;
    }

    /**
        @notice Collateral --> dexIndex
        @dev Currently it is assumed that there is 1:1 collateral <--> dexIndex relationship 
        @dev Since 0 is an invalid value, in the internal structure we need to record the values adding 1 to allow this 
     */
    function _convertCollateralToValidDexIndex(address collateral)
        internal
        view
        returns (uint256)
    {
        require(collateral != address(0), "!collateral");
        require(
            collateralToDexIndex[collateral] != 0,
            "Collateral not supported"
        );
        return collateralToDexIndex[collateral] - 1;
    }

    function _returnAllTokens(IERC20Decimals token, address to) internal {
        if (token.balanceOf(address(this)) > 0) {
            TransferHelper.safeTransfer(
                address(token),
                to,
                token.balanceOf(address(this))
            );
        }
    }

    function _swapWithExactInput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address from,
        address to
    ) internal returns (uint256) {
        require(amountIn > 0, "! tokenIn amount");

        if (from != address(this)) {
            TransferHelper.safeTransferFrom(tokenIn, from, address(this), amountIn);
        }

        uint256 protocolFeesIn = getProtocolFeesTokenIn(tokenIn, amountIn);
        TransferHelper.safeTransfer(tokenIn, feesAccumulator, protocolFeesIn);
        amountIn = protocolFeesIn > 0 ? amountIn - protocolFeesIn : amountIn;

        if (IERC20Decimals(tokenIn).allowance(address(this), address(usdl)) < type(uint256).max) {
            IERC20Decimals(tokenIn).approve(address(usdl), type(uint256).max);
        }
        usdl.depositToWExactCollateral(
            address(this),
            amountIn,
            _convertCollateralToValidDexIndex(tokenIn),
            0,
            IERC20Decimals(tokenIn)
        );

        uint256 usdlAmount = usdl.balanceOf(address(this));
        usdl.withdrawTo(
            address(this),
            usdlAmount,
            _convertCollateralToValidDexIndex(tokenOut),
            amountOutMin,
            IERC20Decimals(tokenOut)
        );
        uint256 wbtcBal = IERC20Decimals(tokenOut).balanceOf(address(this));
        uint256 protocolFeesOut = getProtocolFeesTokenOut(tokenOut, IERC20Decimals(tokenOut).balanceOf(address(this)));
        TransferHelper.safeTransfer(tokenOut, usdl.lemmaTreasury(), protocolFeesOut);
        uint256 netCollateralToGetBack = IERC20Decimals(tokenOut).balanceOf(address(this));
        require(netCollateralToGetBack >= amountOutMin,"! netCollateralToGetBack");
        TransferHelper.safeTransfer(tokenOut, to, netCollateralToGetBack);
        _returnAllTokens(IERC20Decimals(address(usdl)), to);
        return netCollateralToGetBack;
        return 0;
    }
}
