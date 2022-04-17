pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {IMockOracle} from "../interfaces/IMockOracle.sol";
import {Denominations} from "../libs/Denominations.sol";
// import "./interfaces/IPermit.sol";
import "forge-std/console.sol";

// Assumptions 
// quoteToken = vUSD 
// baseToken = Collateral in 1e18 format
contract MockPerp {

    IMockOracle public oracle;
    uint256 public feeOpenShort_1e6;
    uint256 public feeCloseShort_1e6;

    address public defaultQuoteToken;

    // trader --> collateral --> amount
    mapping( address => mapping(address => mapping(address => uint256)) ) public shorts;
    mapping( address => mapping(address => mapping(address => uint256)) ) public openPrice1;

    event Deposited(address, address, uint256, uint256, uint256);
    event Withdrawn(address, address, uint256, uint256, uint256);


    constructor(IMockOracle _oracle, uint256 _feeOpenShort_1e6, uint256 _feeCloseShort_1e6) {
        oracle = _oracle;
        feeOpenShort_1e6 = _feeOpenShort_1e6;
        feeCloseShort_1e6 = _feeCloseShort_1e6;
        defaultQuoteToken = Denominations.USD;
    }


    function computePnLDeltaCollateral(uint256 currentPrice, uint256 openPrice, uint256 collateralAmount, bool isShort) internal returns (int256) {
        if (currentPrice >= openPrice) {
            uint256 perc_1e6 = (currentPrice - openPrice) * 1e6 / openPrice;
        } else {
            uint256 perc_1e6 = (openPrice - currentPrice) * 1e6 / openPrice;
        }
    }

    function openShort1XWExactCollateral(address collateral, uint256 amount) external returns(uint256) {
        uint256 feeAmount = amount * feeOpenShort_1e6 / 1e6;
        TransferHelper.safeTransferFrom(collateral, msg.sender, address(this), feeAmount);

        uint256 actualAmount = amount - feeAmount;


        if (shorts[msg.sender][collateral][defaultQuoteToken] > 0) {
            // Need to compute PnL on the current position

        }

    }

}






