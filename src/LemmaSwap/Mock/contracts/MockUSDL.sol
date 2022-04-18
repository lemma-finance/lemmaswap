pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
// import "../interfaces/IUSDLMock.sol";
// import "../interfaces/IPermit.sol";
// import "../interfaces/ILemmaRouter.sol";
import "forge-std/console.sol";





contract MockLemmaTreasury {}



contract MockUSDL is ERC20 {

    address public lemmaTreasury;
    address public mockPerp;

    uint256 feesUSDLMint;
    uint256 feesUSDLRedeem;
    uint256 feesPerpOpenShort;
    uint256 feesPerpCloseShort;

    // Price Now of a Collateral in USD
    mapping (address => uint256) price;

    event Deposited(address, address, uint256, uint256, uint256);
    event Withdrawn(address, address, uint256, uint256, uint256);

    constructor(
        string memory name,
        string memory symbol,
        address _mockLemmaTreasury
    ) ERC20(name, symbol) {
        lemmaTreasury = _mockLemmaTreasury; 
        // _mint(msg.sender, initialSupply);


        feesUSDLMint = 1000;
        feesUSDLRedeem = 1000;
        feesPerpOpenShort = 1000;
        feesPerpCloseShort = 1000;
    }

    function setPrice(address _collateral, uint256 _price) external {
        price[_collateral] = _price;
    }


    // function getFees(
    //     uint256 dexIndex,
    //     address collateral,
    //     bool isMinting
    // ) external view returns (uint256) {
    //     return 0;
    // }

    function depositToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 minUSDLToMint,
        IERC20 collateral
    ) external {
        uint256 fees = collateralAmount * feesUSDLMint / 1e6; 
        TransferHelper.safeTransferFrom(address(collateral), msg.sender, lemmaTreasury, fees);

        uint256 netCollateral = collateralAmount - fees;
        TransferHelper.safeTransferFrom(address(collateral), msg.sender, address(this), netCollateral);

        uint256 usdlToMint = netCollateral * price[address(collateral)] / 1e18;
        require(usdlToMint > minUSDLToMint, "! minUSDLToMint");
        _mint(to, usdlToMint);
    }

    function withdrawToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 maxUSDLToBurn,
        IERC20 collateral
    ) external {
        uint256 fees = collateralAmount * feesUSDLRedeem / 1e6;
        TransferHelper.safeTransferFrom(address(collateral), address(this), lemmaTreasury, fees);

        uint256 netCollateral = collateralAmount - fees;
        TransferHelper.safeTransferFrom(address(collateral), address(this), to, netCollateral);

        uint256 usdlToBurn = collateralAmount * price[address(collateral)] / 1e18;
        _burn(msg.sender, usdlToBurn);
    }

    // function lemmaTreasury() external view returns (address) {
    //     return 0;
    // }

    function getFees(uint256 dexIndex, address collateral, bool isMinting) external view returns (uint256) {
        return (isMinting) ? feesUSDLMint : feesUSDLRedeem;
    }

    function getTotalPosition(uint256 dexIndex, address collateral) external view returns (int256) {
        return int256(IERC20(collateral).balanceOf(address(this)));
    }

}






