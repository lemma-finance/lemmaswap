// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUSDLemma} from "../interfaces/IUSDLemma.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";

contract LemmaSwap is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    address public feesAccumulator;
    IWETH9 public weth;
    IUSDLemma public usdl;

    // Fees in 1e6 format: 1e6 is 100%
    uint256 public lemmaSwapFees;

    // Assumption: there is 1:1 collateral token to dexIndex relationship
    mapping(address => uint8) public collateralToDexIndex;

    constructor(
        address _usdl,
        address _weth,
        address _feesAccumulator
    ) {
        _setRoleAdmin(OWNER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        grantRole(OWNER_ROLE, msg.sender);
        usdl = IUSDLemma(_usdl);
        weth = IWETH9(_weth);
        feesAccumulator = _feesAccumulator;

        // Initial fee is 0.1%
        lemmaSwapFees = 1000;
    }

    event NewUSDL(address);
    event NewCollateralToDEXIndex(address, uint8);
    event NewLemmaSwapFees(uint256);

    modifier validCollateral(address collateral) {
        require(collateral != address(0), "!collateral");
        _;
    }

    modifier validFees(uint256 fees) {
        require(fees <= 1e6, "!fees");
        _;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "!trade expired");
        _;
    }

    receive() external payable {
        assert(msg.sender == address(weth)); // only accept ETH via fallback from the WETH contract
    }

    function setUSDL(address _usdl) external onlyRole(OWNER_ROLE) {
        require(_usdl != address(0), "! address");
        usdl = IUSDLemma(_usdl);
        emit NewUSDL(address(usdl));
    }

    /**
        @notice Updates the Collateral --> dexIndex association
        @dev The dexIndex is a low level detail that we won't to hide from the UX related methods 
     */
    function setCollateralToDexIndex(address collateral, uint8 dexIndex)
        external
        onlyRole(OWNER_ROLE)
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
        onlyRole(OWNER_ROLE)
        validFees(_fees)
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
    function getProtocolFeesTokenIn(
        address, /*token*/
        uint256 amount
    ) public view returns (uint256) {
        return (amount * getProtocolFeesCoeffTokenIn()) / 1e6;
    }

    /**
        @notice Computes the total amount of fees on output token
     */
    function getProtocolFeesTokenOut(
        address, /*token*/
        uint256 amount
    ) public view returns (uint256) {
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
        @param      deadline        Unix timestamp after which the transaction will revert
        @dev The msg.sender, prior to calling this function, has to approve LemmaSwap for at least the amountIn 
        @dev https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L224
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path.length == 2, "! Multi-hop swap not supported yet");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[1] = _swapWithExactInput(
            path[0],
            amountIn,
            path[1],
            amountOutMin,
            msg.sender,
            to
        );
    }

    /**
        @notice     Swaps an exact amount of ETH for an amount of output tokens that is computed as a function of the input and price 
        @param      amountOutMin    The minimum amount of output token
        @param      path            An array of 2 addresses: input token and output token
        @param      to              Address receiving the output tokens
        @param      deadline        Unix timestamp after which the transaction will revert
        @dev The amountIn is the amount of ETH the msg.sender sends to this function when calling it 
        @dev https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L252
    */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path.length == 2, "! Multi-hop swap not supported yet");
        require(path[0] == address(weth), "! Invalid path");
        weth.deposit{value: msg.value}();
        amounts = new uint256[](path.length);
        amounts[0] = msg.value;
        amounts[1] = _swapWithExactInput(
            address(weth),
            msg.value,
            path[1],
            amountOutMin,
            address(this),
            to
        );
    }

    /**
        @notice     Swaps an exact amount of input tokens for an amount of ETH that is computed as a function of the input and price 
        @param      amountIn        The amount of the input token
        @param      amountOutMin    The minimum amount of ETH to get
        @param      path            An array of 1 address: the input token 
        @param      to              Address receiving the output tokens
        @param      deadline        Unix timestamp after which the transaction will revert
        @dev The msg.sender, prior to calling this function, has to approve LemmaSwap for at least the amountIn 
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path.length == 2, "! Multi-hop swap not supported yet");
        require(path[1] == address(weth), "! Invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[1] = _swapWithExactInput(
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

    /// @notice _swapWithExactInput internal method to swap tokenIn -> tokenOut
    function _swapWithExactInput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address from,
        address to
    ) internal returns (uint256) {
        require(amountIn > 0, "! tokenIn amount");
        uint256 amountIn1e_18 = convertIn18_decimals(IERC20Decimals(tokenIn), amountIn);
        {   
            // static block: to handle stack to deep error
            if (from != address(this)) {
                TransferHelper.safeTransferFrom(
                    tokenIn,
                    from,
                    address(this),
                    amountIn
                );
            }
        
            uint256 protocolFeesInTokenInDecimal = convertInToken_decimals(
                IERC20Decimals(tokenIn), 
                getProtocolFeesTokenIn(tokenIn, amountIn1e_18)
            );
            TransferHelper.safeTransfer(
                tokenIn, 
                feesAccumulator, 
                protocolFeesInTokenInDecimal
            );
            uint256 protocolFees1e_18 = convertIn18_decimals(
                IERC20Decimals(tokenIn), 
                protocolFeesInTokenInDecimal
            );
            amountIn1e_18 = protocolFees1e_18 > 0 ? 
                amountIn1e_18 - protocolFees1e_18 : 
                amountIn1e_18;
            
            // static block end
        }

        if (
            IERC20Decimals(tokenIn).allowance(address(this), address(usdl)) <
            amountIn
        ) {
            IERC20Decimals(tokenIn).approve(address(usdl), type(uint256).max);
        }

        usdl.depositToWExactCollateral(
            address(this),
            amountIn1e_18,
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
            IERC20Decimals(tokenOut).balanceOf(address(this))
        );
        TransferHelper.safeTransfer(
            tokenOut,
            usdl.lemmaTreasury(),
            protocolFeesOut
        );
        uint256 netCollateralToGetBack = IERC20Decimals(tokenOut).balanceOf(
            address(this)
        );
        require(
            netCollateralToGetBack >= amountOutMin,
            "! netCollateralToGetBack"
        );
        TransferHelper.safeTransfer(tokenOut, to, netCollateralToGetBack);
        _returnAllTokens(IERC20Decimals(address(usdl)), to);
        _returnAllTokens(IERC20Decimals(tokenIn), to);
        return netCollateralToGetBack;
    }

    function convertIn18_decimals(IERC20Decimals token, uint256 amount) internal view returns(uint256) {
        uint256 tokenDecimal = token.decimals();
        return ((amount * 1e18) / (10 ** tokenDecimal)); 
    }

    function convertInToken_decimals(IERC20Decimals token, uint256 amount) internal view returns(uint256) {
        uint256 tokenDecimal = token.decimals();
        return ((amount * (10 ** tokenDecimal)) / 1e18); 
    }
    
    function rescueFunds(address token, uint256 amount)
        external
        onlyRole(OWNER_ROLE)
    {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }
}
