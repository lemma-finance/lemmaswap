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



contract MockPerpTreasury {}

// Assumptions 
// quoteToken = vUSD 
// baseToken = Collateral in 1e18 format
contract MockPerp {

    // Price Now of a Collateral in USD
    mapping (address => uint256) public price;

    // IMockOracle public oracle;
    uint256 public feeOpenShort_1e6;
    uint256 public feeCloseShort_1e6;

    address public perpTreasury;

    // address public defaultQuoteToken;

    // trader --> collateral --> amount
    mapping( address => mapping(address => uint256) ) public short_collateral;
    mapping( address => uint256 ) public short_vUSD;
    // mapping( address => mapping(address => mapping(address => uint256)) ) public shorts;
    mapping( address => mapping(address => mapping(address => uint256)) ) public openPrice;

    event Deposited(address, address, uint256, uint256, uint256);
    event Withdrawn(address, address, uint256, uint256, uint256);


    constructor(address _perpTreasury, uint256 _feeOpenShort_1e6, uint256 _feeCloseShort_1e6) {
        // oracle = _oracle;
        feeOpenShort_1e6 = _feeOpenShort_1e6;
        feeCloseShort_1e6 = _feeCloseShort_1e6;
        // defaultQuoteToken = Denominations.USD;
        perpTreasury = _perpTreasury;
    }

    function _takeFees(address collateral, uint256 amount, bool isOpenShort) internal returns(uint256) {
        uint256 absFees = ((isOpenShort) ? feeOpenShort_1e6 : feeCloseShort_1e6) * amount / 1e6;
        TransferHelper.safeTransferFrom(collateral, msg.sender, address(perpTreasury), absFees); 
        return amount - absFees;
    }

    function setPrice(address _collateral, uint256 _price) external {
        price[_collateral] = _price;
    }


    // function computeUpdatedCollateralAmount(uint256 currentPrice, uint256 openPrice, uint256 collateralAmount, bool isShort) internal pure returns (uint256) {
    //     uint256 res = collateralAmount;
    //     if (currentPrice > openPrice) {
    //         uint256 coeff_1e6 = 1e6 + ((currentPrice - openPrice) * 1e6 / openPrice);

    //         return (isShort) ? collateralAmount / coeff_1e6 : collateralAmount * coeff_1e6;

    //     } else {
    //         uint256 coeff_1e6 = 1e6 + ((openPrice - currentPrice) * 1e6 / openPrice);

    //         return (isShort) ? collateralAmount * coeff_1e6 : collateralAmount / coeff_1e6;
    //     }
    // }

    function openShort1XWExactCollateral(address collateral, uint256 amount) external returns(uint256) {
        require(price[collateral] != 0, "Unsupported Collateral");
        uint256 netCollateralAmount = _takeFees(collateral, amount, true);
        TransferHelper.safeTransferFrom(address(collateral), msg.sender, address(this), netCollateralAmount);
        short_collateral[msg.sender][collateral] += netCollateralAmount;
        uint256 vUSDAmount = netCollateralAmount * 1e18 / price[address(collateral)];
        short_vUSD[msg.sender] += vUSDAmount;
        return vUSDAmount;

        // shorts[msg.sender][collateral][defaultQuoteToken] += netCollateralAmount;

        // if (shorts[msg.sender][collateral][defaultQuoteToken] > 0) {
        //     // Need to compute PnL on the current position
        //     shorts[msg.sender][collateral][defaultQuoteToken] = computeUpdatedCollateralAmount(
        //         oracle.getPriceNow(collateral, defaultQuoteToken),
        //         openPrice[msg.sender][collateral][defaultQuoteToken],
        //         shorts[msg.sender][collateral][defaultQuoteToken],
        //         true
        //     );
        // }

    }

}






