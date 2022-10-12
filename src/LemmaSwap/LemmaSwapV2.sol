// SPDX-License-Identifier: UNLICENSED
//NOT BEING USED IN PRODUCTION
pragma solidity 0.8.14;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUSDLemma} from "../interfaces/IUSDLemma.sol";
import {IPerpLemma} from "../interfaces/IPerpLemma.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";

contract LemmaSwapV2 is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // feesAccumulator, where all fees accumulate from tokenIn and tokenOut
    address public feesAccumulator;
    // Weth erc20 token
    IWETH9 public weth;
    // usdl erc20 token
    IUSDLemma public usdl;

    // Fees in 1e6 format: 1e6 is 100%
    uint256 public lemmaSwapFees;

    // for all the perp collaterals, we set 0 in usdl contracts
    // so it is fixed(dexIndex = 0)
    uint256 public dexIndex = 0;

    // Assumption: there is 1:1 collateral token to dexIndex relationship
    mapping(address => uint8) public collateralToDexIndex;
    // Collateral to perpDexWrapper mapping(It should be same like usdl perpDex mapping)
    mapping(address => address) public perpetualDEXWrappers;

    /// @param _usdl usdLemma contract address
    /// @param _weth Weth erc20 contract address
    /// @param _feesAccumulator contract address, where all fees accumulate from tokenIn and tokenOut
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

    // Events
    event NewUSDL(address);
    event NewFeesAccumulator(address);
    event NewCollateralToDEXIndex(address, uint8);
    event NewLemmaSwapFees(uint256);
    event PerpetualDexWrapperAdded(
        address indexed collateral,
        address indexed dexWrapper
    );

    /**
        @notice Check collateral is not zero address
    */
    modifier validCollateral(address collateral) {
        require(collateral != address(0), "!collateral");
        _;
    }

    /**
        @notice Check fees is not le to 1e6
    */
    modifier validFees(uint256 fees) {
        require(fees <= 1e6, "!fees");
        _;
    }

    /**
        @notice Check deadline is not pass
    */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "!trade expired");
        _;
    }

    /**
        @notice fallback function
    */
    receive() external payable {
        assert(msg.sender == address(weth)); // only accept ETH via fallback from the WETH contract
    }

    /**
        @notice rescueFunds function will take all the unnecessary funds to safe address 
    */
    function rescueFunds(address token, uint256 amount)
        external
        onlyRole(OWNER_ROLE)
    {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    /**
        @notice addPerpetualDEXWrapper set perpDexAddress for specific collateral from usdl contract
    */
    function addPerpetualDEXWrapper(address collateralAddress)
        public
        onlyRole(OWNER_ROLE)
    {
        address perpDEXWrapper = usdl.perpetualDEXWrappers(
            dexIndex,
            collateralAddress
        );
        require(
            address(perpDEXWrapper) != address(0),
            "DEX Wrapper should not ZERO address"
        );
        perpetualDEXWrappers[collateralAddress] = perpDEXWrapper;
        emit PerpetualDexWrapperAdded(collateralAddress, perpDEXWrapper);
    }

    /**
        @notice setUSDL set address of usdLemma contract address 
    */
    function setUSDL(address _usdl) external onlyRole(OWNER_ROLE) {
        require(_usdl != address(0), "! address");
        usdl = IUSDLemma(_usdl);
        emit NewUSDL(address(usdl));
    }

    /**
        @notice setFeeAccumulator set address 
        where all the tokenIn and tokenOut fees will accumulate 
    */
    function setFeeAccumulator(address _feesAccumulator)
        external
        onlyRole(OWNER_ROLE)
    {
        require(_feesAccumulator != address(0), "! address");
        feesAccumulator = _feesAccumulator;
        emit NewFeesAccumulator(_feesAccumulator);
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

    /**
        @notice getAdjustedOutputAmount will compute output ampunt after fees
     */
    function getAdjustedOutputAmount(address token, uint256 amount)
        external
        view
        returns (uint256)
    {
        uint256 _dexIndex = _convertCollateralToValidDexIndex(token);
        uint256 redeemFees = usdl.getFees(_dexIndex, token, false);
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
    )
        external
        nonReentrant
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
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
    )
        external
        payable
        nonReentrant
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
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
    )
        external
        nonReentrant
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
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

    /// @notice _swapWithExactInput internal method to swap tokenIn -> tokenOut
    function _swapWithExactInput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address from,
        address to
    ) internal returns (uint256) {
        IPerpLemma perpDEXWrapperIn = IPerpLemma(perpetualDEXWrappers[tokenIn]);
        IPerpLemma perpDEXWrapperOut = IPerpLemma(
            perpetualDEXWrappers[tokenOut]
        );

        require(amountIn > 0, "! tokenIn amount");
        {
            // static block: to handle stack to deep error
            uint256 protocolFeesInTokenInDecimal = getProtocolFeesTokenIn(
                tokenIn,
                amountIn
            );
            TransferHelper.safeTransferFrom(
                tokenIn,
                from,
                feesAccumulator,
                protocolFeesInTokenInDecimal
            );
            amountIn = protocolFeesInTokenInDecimal > 0
                ? amountIn - protocolFeesInTokenInDecimal
                : amountIn;

            // static block end
        }

        uint256 amountIn1e_18 = convertIn18_decimals(
            IERC20Decimals(tokenIn),
            amountIn
        );

        if (from != address(this)) {
            // for other tokens
            TransferHelper.safeTransferFrom(
                tokenIn,
                from,
                address(perpDEXWrapperIn),
                amountIn
            );
        } else {
            // for swapExactETHForTokens method
            // becuase after deposit Eth into WethContract, new minted weth will be with address(this) only
            TransferHelper.safeTransfer(
                tokenIn,
                address(perpDEXWrapperIn),
                amountIn
            );
        }
        perpDEXWrapperIn.deposit(amountIn, tokenIn);
        (, uint256 quote) = perpDEXWrapperIn.openShortWithExactBase(
            amountIn1e_18
        );
        perpDEXWrapperIn.calculateMintingAsset(
            quote,
            IPerpLemma.Basis.IsUsdl,
            true
        );

        (uint256 base, ) = perpDEXWrapperOut.closeShortWithExactQuote(quote);
        uint256 baseInTokenDecimal = convertInToken_decimals(
            IERC20Decimals(tokenOut),
            base
        );
        perpDEXWrapperOut.withdraw(baseInTokenDecimal, tokenOut);

        uint256 protocolFeesOut = getProtocolFeesTokenOut(
            tokenOut,
            baseInTokenDecimal
        );

        uint256 netCollateralToGetBack = baseInTokenDecimal - protocolFeesOut;

        TransferHelper.safeTransferFrom(
            tokenOut,
            address(perpDEXWrapperOut),
            feesAccumulator,
            protocolFeesOut
        );
        TransferHelper.safeTransferFrom(
            tokenOut,
            address(perpDEXWrapperOut),
            to,
            netCollateralToGetBack
        );

        require(
            netCollateralToGetBack >= amountOutMin,
            "! netCollateralToGetBack"
        );
        return netCollateralToGetBack;
    }

    function convertIn18_decimals(IERC20Decimals token, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 tokenDecimal = token.decimals();
        return ((amount * 1e18) / (10**tokenDecimal));
    }

    function convertInToken_decimals(IERC20Decimals token, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 tokenDecimal = token.decimals();
        return ((amount * (10**tokenDecimal)) / 1e18);
    }
}
