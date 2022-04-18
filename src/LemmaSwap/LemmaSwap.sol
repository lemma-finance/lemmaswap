pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {IUSDLSwapSubset} from "../interfaces/IUSDLSwapSubset.sol";
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

    constructor(
        // ILemmaRouter _lemmaRouter, 
        IUSDLSwapSubset _usdl) {
        owner = msg.sender;
        // lemmaRouter = _lemmaRouter; 
        usdl = _usdl;

        // The standard is 0.1% 
        lemmaSwapFees = 1000;

        usdl.approve(address(lemmaRouter), type(uint256).max);
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

    function _returnAllTokens(IERC20 token) internal {
        if (token.balanceOf(address(this)) > 0) {
            TransferHelper.safeTransfer(
                address(token),
                msg.sender,
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

    function getProtocolFees(sToken memory tokenIn) public view returns(uint256) {
        return tokenIn.amount * lemmaSwapFees / 1e6;
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

    function swapWithExactOutput(
        sToken memory tokenIn,
        sToken memory tokenOut
    ) external returns (uint256) {

        // require(collateralToDexIndex[address(tokenIn.token)] != address(0), "! collateral tokenIn");
        // require(collateralToDexIndex[address(tokenOut.token)] != address(0), "! collateral tokenOut");

        require(tokenIn.amount > 0, "! tokenIn amount");
        require(tokenOut.amount > 0, "! tokenOut amount");

        console.log("[LemmaSwap swapWithExactOutput()] TokenIn Amount ", tokenIn.amount);
        console.log("[LemmaSwap swapWithExactOutput()] collateralToDexIndex[address(tokenIn.token)] ", convertCollateralToValidDexIndex(address(tokenIn.token)));

        TransferHelper.safeTransferFrom(
            address(tokenIn.token),
            msg.sender,
            address(this),
            tokenIn.amount
        );

        console.log("[LemmaSwap] Balance TokenIn Before = ", tokenIn.token.balanceOf(address(this)));

        uint256 protocolFees = getProtocolFees(tokenIn);
        TransferHelper.safeTransfer(
            address(tokenIn.token),
            usdl.lemmaTreasury(),
            protocolFees
        );
        
        console.log("[LemmaSwap] protocolFees = ", protocolFees);
        console.log("[LemmaSwap] LemmaTreasury = ", usdl.lemmaTreasury());

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
        uint256 expectedOutput = tokenOut.amount;
        tokenOut.amount = getAdjustedOutputAmount(tokenOut);

        usdl.withdrawToWExactCollateral(
            msg.sender,
            tokenOut.amount,
            convertCollateralToValidDexIndex(address(tokenOut.token)),
            type(uint256).max,
            tokenOut.token
        );

        //_returnAllTokens(tokenIn.token);
        _returnAllTokens(usdl);

        return tokenOut.amount;
    }


}

