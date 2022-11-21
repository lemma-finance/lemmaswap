// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUSDLemma} from "../interfaces/IUSDLemma.sol";
// import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import {IXUSDL} from "../interfaces/IXUSDL.sol";
import {IXLemmaSynth} from "../interfaces/IXLemmaSynth.sol";
import {ILemmaSwap} from "../interfaces/ILemmaSwap.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";


contract USDL1{
    address public xUsdl;
    mapping(uint256 => mapping(address => address)) public perpetualDEXWrappers;
    address public perpSettlementToken;
}

contract LemmaSynth1 {
    address public xSynth;
}

contract Perp1{
    address public lemmaSynth;
}


// NOTE: They both share this same interface
interface IUSDLAndSynth {
    function depositToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 minUSDLToMint,
        IERC20 collateral
    ) external;
}

/// @author Lemma Finance
/// @notice LemmaSwap contract to execute spot trades using futures’ liquidity
contract LemmaSwap is AccessControl, ReentrancyGuard, ILemmaSwap {
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

    // Assumption: there is 1:1 collateral token to dexIndex relationship
    // this would be break when we integrate anohter perpetual DEX
    mapping(address => uint8) public collateralToDexIndex;

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
    event NewXUSDL(address);
    event NewFeesAccumulator(address);
    event NewCollateralToDEXIndex(address, uint8);
    event NewLemmaSwapFees(uint256);

    /**
        @notice Check collateral is not zero address
    */
    modifier validCollateral(address collateral) {
        require(collateral != address(0), "Collateral is not valid");
        _;
    }

    /**
        @notice Check fees is not le to 1e6
    */
    modifier validFees(uint256 fees) {
        require(fees <= 1e6, "Fees out of range");
        _;
    }

    /**
        @notice Check deadline is not pass
    */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "Trade expired");
        _;
    }

    /**
        @notice fallback function
    */
    receive() external payable {
        assert(msg.sender == address(weth)); // only accept ETH via fallback from the WETH contract
    }

    /**
        @notice setUSDL set address of usdLemma contract address 
    */
    function setUSDL(address _usdl) external onlyRole(OWNER_ROLE) {
        require(_usdl != address(0), "Zero address is not allowed");
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
        require(_feesAccumulator != address(0), "Zero address is not allowed");
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
        @notice LemmaSwap fees to be taken on token
        @dev The fees are in 1e6 format
     */
    function getProtocolFeesCoeff() public view returns (uint256) {
        return (lemmaSwapFees / 2);
    }

    /**
        @notice Computes the total amount of fees on output token
     */
    function getProtocolFees(address token, uint256 amount)
        public
        view
        returns (uint256)
    {
        return (amount * getProtocolFeesCoeff()) / 1e6;
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
        require(path.length == 2, "Multi-hop swap not supported yet");
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
        require(path.length == 2, "Multi-hop swap not supported yet");
        require(path[0] == address(weth), "Invalid path");
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
        require(path.length == 2, "Multi-hop swap not supported yet");
        require(path[1] == address(weth), "Invalid path");
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
        require(collateral != address(0), "Zero address is not allowed");
        require(
            collateralToDexIndex[collateral] != 0,
            "Collateral is not supported"
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
    ) internal returns (uint256 amountOut) {
        require(amountIn > 0, "Zero amountIn is not allowed");
        if (from != address(this)) {
            TransferHelper.safeTransferFrom(
                tokenIn,
                from,
                address(this),
                amountIn
            );
        }

        uint256 protocolFeesIn = getProtocolFees(tokenIn, amountIn);
        TransferHelper.safeTransfer(tokenIn, feesAccumulator, protocolFeesIn);
        amountIn = amountIn - protocolFeesIn;

        uint256 amountIn18Decimals = convertAmountIn18Decimals(
            IERC20Decimals(tokenIn),
            amountIn
        );

        // give approval of tokenIn to USDL if not given already
        if (
            IERC20Decimals(tokenIn).allowance(address(this), address(usdl)) <
            amountIn
        ) {
            IERC20Decimals(tokenIn).approve(address(usdl), type(uint256).max);
        }

        if (tokenIn == address(usdl)) {
            // burn USDL getting tokenOut collateral back
            usdl.withdrawTo(
                address(this),
                amountIn18Decimals,
                _convertCollateralToValidDexIndex(tokenOut),
                amountOutMin,
                IERC20(tokenOut)
            );
        } else if (tokenOut == address(usdl)) {
            // mint USDL with tokenIn as collateral
            usdl.depositToWExactCollateral(
                address(this),
                amountIn18Decimals,
                _convertCollateralToValidDexIndex(tokenIn),
                0,
                IERC20(tokenIn)
            );
        } else {
            // mint USDL with tokenIn as collateral
            usdl.depositToWExactCollateral(
                address(this),
                amountIn18Decimals,
                _convertCollateralToValidDexIndex(tokenIn),
                0,
                IERC20(tokenIn)
            );
            uint256 usdlAmount = usdl.balanceOf(address(this));
            // burn USDL getting tokenOut collateral back
            usdl.withdrawTo(
                address(this),
                usdlAmount,
                _convertCollateralToValidDexIndex(tokenOut),
                amountOutMin,
                IERC20(tokenOut)
            );
        }

        amountOut = IERC20Decimals(tokenOut).balanceOf(address(this));
        uint256 protocolFeesOut = getProtocolFees(tokenOut, amountOut);
        TransferHelper.safeTransfer(tokenOut, feesAccumulator, protocolFeesOut);

        amountOut = amountOut - protocolFeesOut;
        require(amountOut >= amountOutMin, "Insufficient amountOut");
        if (to != address(this)) {
            TransferHelper.safeTransfer(tokenOut, to, amountOut);
        }
    }

    /**
        @notice convertAmountIn18Decimals convert amount in token decimals to 1e18 decimals
    */
    function convertAmountIn18Decimals(IERC20Decimals token, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 tokenDecimal = token.decimals();
        return ((amount * 1e18) / (10**tokenDecimal));
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


    // function _addLiquidity1(address token, uint256 amount, address to) internal returns(uint256 amountOut) {
    //     IXUSDL xusdl = IXUSDL(USDL1(address(usdl)).xUsdl());

    //     uint256 usdlBefore = usdl.balanceOf(address(this)); 
    //     // NOTE: Atm just minting USDL as it is generic enough for any collateral
    //     usdl.depositToWExactCollateral(
    //         address(this),
    //         convertAmountIn18Decimals(IERC20Decimals(token), amount),
    //         _convertCollateralToValidDexIndex(token),
    //         0,
    //         IERC20(token)
    //     );
    //     uint256 usdlAfter = usdl.balanceOf(address(this)); 
    //     require(usdlAfter > usdlBefore, "amount");
    //     uint256 amountToDeposit = usdlAfter - usdlBefore;
    //     amountOut = xusdl.deposit(amountToDeposit, to);
    // }



    function _mintWithExactCollateral(IUSDLAndSynth usdlOrSynth, IERC20Decimals token, uint256 amount) internal returns(uint256 amountUSDL) {
        uint256 amountBefore = IERC20Decimals(address(usdlOrSynth)).balanceOf(address(this)); 
        TransferHelper.safeTransferFrom(address(token), msg.sender, address(this), amount);
        token.approve(address(usdlOrSynth), amount);
        usdlOrSynth.depositToWExactCollateral(
            address(this),
            convertAmountIn18Decimals(token, amount),
            _convertCollateralToValidDexIndex(address(token)),
            0,
            IERC20(token)
        );
        uint256 amountAfter = IERC20Decimals(address(usdlOrSynth)).balanceOf(address(this)); 
        require(amountAfter > amountBefore, "amount");
        amountUSDL = amountAfter - amountBefore;
    }

    // function _addLiquidity2(address token, uint256 amount, address to) internal returns(uint256 amountOut) {
    //     IXUSDL xusdl = IXUSDL(USDL1(address(usdl)).xUsdl());
    //     address perpSettlementToken = USDL1(address(usdl)).perpSettlementToken();

    //     // NOTE: All of this has been done to avoid adding one more state variable which makes the upgrade more difficult. 
    //     // NOTE: Also, it assumes LemmaSynth is the generic entry point for all the N PerpDEXWrappers so that any of the N PerpDEXWrappers point to the same LemmaSynt Contract
    //     address perpSettlementTokenDEXWrapper = USDL1(address(usdl)).perpetualDEXWrappers(0, perpSettlementToken);
    //     ILemmaSynth lemmaSynth = ILemmaSynth(Perp1((perpSettlementTokenDEXWrapper)).lemmaSynth());

    //     uint256 amountToDeposit; 
    //     if(token == perpSettlementToken) {
    //         amountToDeposit = _mintUSDLWithExactCollateral(IERC20Decimals(token), amount);
    //     } else {
    //         // TODO: Implement
    //     }
    //     amountOut = xusdl.deposit(amountToDeposit, to);
    // }

    function _addLiquidity(address tokenIn, uint256 amountIn, address to) internal returns(address tokenOut, uint256 amountOut) {
        address perpSettlementToken = USDL1(address(usdl)).perpSettlementToken();
        if(tokenIn == perpSettlementToken) {
            // NOTE: USDC --> USDL 
            tokenOut = address(usdl);
            amountOut = _mintWithExactCollateral(IUSDLAndSynth(tokenOut), IERC20Decimals(tokenIn), amountIn);
            amountOut = IXUSDL(USDL1(tokenOut).xUsdl()).deposit(amountOut, to);
        } else {
            // NOTE: Variable Collateral --> Corresponding Synth
            address perpTokenDEXWrapper = USDL1(address(usdl)).perpetualDEXWrappers(0, tokenIn);
            tokenOut = Perp1(perpTokenDEXWrapper).lemmaSynth();
            amountOut = _mintWithExactCollateral(IUSDLAndSynth(tokenOut), IERC20Decimals(tokenIn), amountIn);
            amountOut = IXLemmaSynth(LemmaSynth1(tokenOut).xSynth()).deposit(amountOut, to);
        }
    }


    function _addLiquidityStable(address stable, address tokenForSynth, uint256 amountIn, address to) internal returns(address tokenOut, uint256 amountOut) {
        address perpSettlementToken = USDL1(address(usdl)).perpSettlementToken();
        require(stable == perpSettlementToken, "PerpSettlementToken");
        // NOTE: USDC --> USDL 
            // NOTE: Variable Collateral --> Corresponding Synth
        address perpTokenDEXWrapper = USDL1(address(usdl)).perpetualDEXWrappers(0, tokenForSynth);
        // address lemmaSynth = Perp1(perpTokenDEXWrapper).lemmaSynth();
        tokenOut = Perp1(perpTokenDEXWrapper).lemmaSynth();
        amountOut = _mintWithExactCollateral(IUSDLAndSynth(tokenOut), IERC20Decimals(stable), amountIn);
        amountOut = IXLemmaSynth(LemmaSynth1(tokenOut).xSynth()).deposit(amountOut, to);
    }


    function _addLiquidityVariable(address tokenIn, uint256 amountIn, address to) internal returns(address tokenOut, uint256 amountOut) {
        tokenOut = address(usdl);
        amountOut = _mintWithExactCollateral(IUSDLAndSynth(tokenOut), IERC20Decimals(tokenIn), amountIn);
        amountOut = IXUSDL(USDL1(tokenOut).xUsdl()).deposit(amountOut, to);
    }

    // function addLiquidityIgnoreTokenB(
    //     address token,
    //     address tokenIgnored,
    //     uint256 amountDesired,
    //     uint256 amountIgnored,
    //     uint256 amountMin,
    //     uint256 amountMinIgnored,
    //     address to,
    //     uint256 deadline
    // ) external /*override*/ returns (uint256 amountIn, uint256 amountInIgnored, uint256 liquidity) {
    //     require(amountDesired > 0, "Zero Amount");
    //     require(to != address(0), "Invalid recipient");
    //     require(block.timestamp <= deadline, "Expired");
    //     amountIn = amountDesired;
    //     liquidity = _addLiquidity1(token, amountIn, msg.sender);
    // }


    // function addLiquidity1(
    //     address tokenStable,
    //     address tokenVariable,
    //     uint256 amountStableDesired,
    //     uint256 amountVariableDesired,
    //     uint256 amountStableMin,
    //     uint256 amountVariableMin,
    //     address to,
    //     uint256 deadline
    // ) external override returns (uint256 amountStableIn, uint256 amountVariableIn, uint256 amountXSynth) {
    //     require(amountStableDesired > 0, "Zero Stable Amount");
    //     require(amountVariableDesired > 0, "Zero Variable Amount");
    //     require(to != address(0), "Invalid recipient");
    //     require(block.timestamp <= deadline, "Expired");

    //     require(tokenStable == USDL1(address(usdl)).perpSettlementToken(), "tokenA has to be SettlementToken");
    //     amountStableIn = amountStableDesired;
    //     _addLiquidity2(tokenStable, amountStableIn, msg.sender);
    //     amountXSynth = _addLiquidity2(tokenVariable, amountVariableIn, msg.sender);
    // }



    // function addLiquidity_OldProposal(
    //     address tokenA,
    //     address tokenB,
    //     uint256 amountA,
    //     uint256 amountB,
    //     uint256 unusedA,
    //     uint256 unusedB,
    //     address to,
    //     uint256 deadline
    // ) external override returns (uint256 amountXA, uint256 amountXB, uint256 unused) {
    //     require(amountA > 0, "Zero A Amount");
    //     require(amountB > 0, "Zero B Amount");
    //     require(to != address(0), "Invalid recipient");
    //     require(block.timestamp <= deadline, "Expired");

    //     (, amountXA) = _addLiquidity(tokenA, amountA, to);
    //     (, amountXB) = _addLiquidity(tokenB, amountB, to);
    // }



    function addLiquidity(
        address stable,
        address variable,
        uint256 amountStable,
        uint256 amountVariable,
        uint256 unusedStable,
        uint256 unusedVariable,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountXA, uint256 amountXB, uint256 unused) {
        require(amountStable > 0, "Zero Stable Amount");
        require(amountVariable > 0, "Zero Variable Amount");
        require(to != address(0), "Invalid recipient");
        require(block.timestamp <= deadline, "Expired");

        (, amountXA) = _addLiquidityStable(stable, variable, amountStable, to);
        (, amountXB) = _addLiquidity(variable, amountVariable, to);
    }


}
