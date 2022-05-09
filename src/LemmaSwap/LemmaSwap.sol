pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUSDLSwapSubset} from "../interfaces/IUSDLSwapSubset.sol";
import {IWETH10} from "@weth10/interfaces/IWETH10.sol";
import "../interfaces/ILemmaRouter.sol";

interface IERC20Decimal is IERC20 {
    function decimals() external view returns (uint256);
}

contract LemmaSwap {
    address public owner;
    ILemmaRouter public lemmaRouter;
    mapping(address => uint8) public collateralToDexIndex;

    IUSDLSwapSubset public usdl;

    // Fees in 1e6 format: 1e6 is 100%
    uint256 public lemmaSwapFees;

    IWETH10 public weth;

    constructor(address _usdl, address _weth) {
        owner = msg.sender;
        usdl = IUSDLSwapSubset(_usdl);
        weth = IWETH10(_weth);

        // Initial fee is 0.1%
        lemmaSwapFees = 1000;
    }

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

    fallback() external payable {}

    receive() external payable {}

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
            path[0],
            amountIn,
            path[1],
            amountOutMin,
            to
        );
        return res;
    }

    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L252
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
        require(path.length == 1, "! Multi-hop swap not supported yet");
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

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length == 1, "! Multi-hop swap not supported yet");
        uint256[] memory res = new uint256[](1);
        res[0] = swapWithExactInput(
            path[0],
            amountIn,
            address(weth),
            amountOutMin,
            address(this)
        );
        uint256 wethAmount = weth.balanceOf(address(this));
        require(wethAmount > amountOutMin, "! Amount Out Min");
        weth.withdraw(wethAmount);
        TransferHelper.safeTransferETH(to, wethAmount);
        return res;
    }

    /**
        @notice Swaps an exact token input amount for an exact token output amount
        @dev Constraint: setting both input and output amount defines the swap price implicitly and this price can't be <= than the vAMM price, if so the TX reverts of course 
        @dev The price can be >= than the vAMM price, in that case some extra USDL is minted and returned to the `to` address
     */
    function swapWithExactInputAndOutput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut,
        address to
    ) public returns (uint256) {
        require(amountIn > 0, "! tokenIn amount");
        require(amountOut > 0, "! tokenOut amount");

        TransferHelper.safeTransferFrom(
            address(tokenIn),
            msg.sender,
            address(this),
            amountIn
        );

        uint256 protocolFeesIn = getProtocolFeesTokenIn(tokenIn, amountIn);
        TransferHelper.safeTransfer(
            tokenIn,
            usdl.lemmaTreasury(),
            getProtocolFeesTokenIn(tokenIn, amountIn)
        );

        amountIn = IERC20(tokenIn).balanceOf(address(this));

        if (
            IERC20(tokenIn).allowance(address(this), address(usdl)) <
            type(uint256).max
        ) {
            IERC20(tokenIn).approve(address(usdl), type(uint256).max);
        }

        usdl.depositToWExactCollateral(
            address(this),
            amountIn,
            _convertCollateralToValidDexIndex(tokenIn),
            0,
            IERC20(tokenIn)
        );

        uint256 protocolFeesOut = getProtocolFeesTokenOut(tokenOut, amountOut);
        usdl.withdrawToWExactCollateral(
            address(this),
            amountOut + protocolFeesOut,
            _convertCollateralToValidDexIndex(tokenOut),
            type(uint256).max,
            IERC20(tokenOut)
        );

        TransferHelper.safeTransfer(
            tokenOut,
            usdl.lemmaTreasury(),
            getProtocolFeesTokenOut(tokenOut, amountOut)
        );

        // console.log("[LemmaSwap] protocolFeesOut = ", protocolFeesOut);

        uint256 netCollateralToGetBack = IERC20(tokenOut).balanceOf(
            address(this)
        );

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
        uint256 amountOutMin,
        address to
    ) public returns (uint256) {
        return
            _swapWithExactInput(
                tokenIn,
                amountIn,
                tokenOut,
                amountOutMin,
                msg.sender,
                to
            );
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
            TransferHelper.safeTransferFrom(
                tokenIn,
                from,
                address(this),
                amountIn
            );
        }

        uint256 protocolFeesIn = getProtocolFeesTokenIn(tokenIn, amountIn);
        TransferHelper.safeTransfer(
            tokenIn,
            usdl.lemmaTreasury(),
            getProtocolFeesTokenIn(tokenIn, amountIn)
        );

        if (
            IERC20(tokenIn).allowance(address(this), address(usdl)) <
            type(uint256).max
        ) {
            IERC20(tokenIn).approve(address(usdl), type(uint256).max);
        }

        usdl.depositToWExactCollateral(
            address(this),
            IERC20(tokenIn).balanceOf(address(this)),
            _convertCollateralToValidDexIndex(tokenIn),
            0,
            IERC20(tokenIn)
        );

        uint256 usdlAmount = usdl.balanceOf(address(this));

        usdl.withdrawTo(
            address(this),
            usdlAmount,
            _convertCollateralToValidDexIndex(tokenOut),
            amountOutMin,
            IERC20(tokenOut)
        );

        uint256 protocolFeesOut = getProtocolFeesTokenOut(
            tokenOut,
            IERC20(tokenOut).balanceOf(address(this))
        );

        TransferHelper.safeTransfer(
            tokenOut,
            usdl.lemmaTreasury(),
            protocolFeesOut
        );

        uint256 netCollateralToGetBack = IERC20(tokenOut).balanceOf(
            address(this)
        );

        require(
            netCollateralToGetBack >= amountOutMin,
            "! netCollateralToGetBack"
        );

        TransferHelper.safeTransfer(tokenOut, to, netCollateralToGetBack);

        _returnAllTokens(usdl, to);

        return netCollateralToGetBack;
    }


}
