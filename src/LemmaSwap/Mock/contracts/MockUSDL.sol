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
    address public lemmaSwap;

    uint256 feesUSDLMint;
    uint256 feesUSDLRedeem;
    uint256 feesPerpOpenShort;
    uint256 feesPerpCloseShort;

    uint256 feesSwap;

    // Price Now of a Collateral in USD
    mapping (address => uint256) public price;

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
        feesSwap = 3000;
    }

    function setPrice(address _collateral, uint256 _price) external {
        price[_collateral] = _price;
    }

    function setLemmaSwap(address _lemmaSwap) external {
        lemmaSwap = _lemmaSwap;
    }


    // function getFees(
    //     uint256 dexIndex,
    //     address collateral,
    //     bool isMinting
    // ) external view returns (uint256) {
    //     return 0;
    // }

    // Converts USDL amount to Collateral amount at oracle price
    function USDL2Collateral(address collateral, uint256 amount) public view returns (uint256) {
        require(price[collateral] != 0, "Unsupported Collateral");
        return amount * 1e18 / price[address(collateral)]; 
    }

    function Collateral2USDL(address collateral, uint256 amount) public view returns (uint256) { 
        require(price[collateral] != 0, "Unsupported Collateral");
        return amount * price[address(collateral)] / 1e18;
    }

    function getLemmaFees(uint256 dexIndex, IERC20 collateral, uint256 amount, bool isMinting) public returns(uint256) {
        // TODO: Replace with calls to consulting contract
        return ( (isMinting) ? feesUSDLMint : feesUSDLRedeem ) * amount / 1e6;
    }

    function _takeFees(uint256 dexIndex, IERC20 collateral, uint256 amount, bool isMinting) internal returns(uint256) {
        if (msg.sender == lemmaSwap) return amount;
        uint256 absFees = getLemmaFees(dexIndex, collateral, amount, isMinting);

        // // If minting, we take fees from the input collateral 
        // // If redeeming, first we get collateral to this contract and then take the fees from ourselves before transfering the rest to the `to` address
        if(isMinting) {
            TransferHelper.safeTransferFrom(address(collateral), msg.sender, address(lemmaTreasury), absFees);            
        }
        else {
            TransferHelper.safeTransfer(address(collateral), address(lemmaTreasury), absFees);
        }

        return amount - absFees;
    }

    function depositTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 maxCollateralAmountRequired,
        IERC20 collateral,
        bool isLemmaSwap
    ) public {
        uint256 collateralAmount = USDL2Collateral(address(collateral), amount);
        uint256 netCollateralAmount = _takeFees(0, collateral, collateralAmount, true);
        // uint256 fees = collateralAmount * feesUSDLMint / 1e6; 
        // TransferHelper.safeTransferFrom(address(collateral), msg.sender, lemmaTreasury, fees);
        TransferHelper.safeTransferFrom(address(collateral), msg.sender, address(this), netCollateralAmount);
        _mint(to, amount);  
    }



    function depositToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 minUSDLToMint,
        IERC20 collateral
    ) external {
        uint256 netCollateral = _takeFees(0, collateral, collateralAmount, true);

        // uint256 fees = collateralAmount * feesUSDLMint / 1e6; 
        // TransferHelper.safeTransferFrom(address(collateral), msg.sender, lemmaTreasury, fees);

        // uint256 netCollateral = collateralAmount - fees;
        TransferHelper.safeTransferFrom(address(collateral), msg.sender, address(this), netCollateral);

        uint256 usdlToMint = Collateral2USDL(address(collateral), netCollateral);
        require(usdlToMint > minUSDLToMint, "! minUSDLToMint");
        _mint(to, usdlToMint);
    }

    function withdrawTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 minCollateralAmountToGetBack,
        IERC20 collateral
    ) public {
        uint256 collateralAmount = USDL2Collateral(address(collateral), amount);
        uint256 netCollateralToGetBack = _takeFees(perpetualDEXIndex, collateral, collateralAmount, false);
        // uint256 fees = collateralAmount * feesUSDLRedeem / 1e6; 
        // TransferHelper.safeTransferFrom(address(collateral), address(this), lemmaTreasury, fees);
        TransferHelper.safeTransfer(address(collateral), msg.sender, netCollateralToGetBack);
        _burn(to, amount)  ;
    }

    function withdrawToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 maxUSDLToBurn,
        IERC20 collateral
    ) external {
        uint256 netCollateralToGetBack = _takeFees(perpetualDEXIndex, collateral, collateralAmount, false);
        console.log("withdrawToWExactCollateral() collateralAmount = ", collateralAmount);
        console.log("withdrawToWExactCollateral() netCollateralToGetBack = ", netCollateralToGetBack);
        // uint256 fees = collateralAmount * feesUSDLRedeem / 1e6;
        // TransferHelper.safeTransfer(address(collateral), lemmaTreasury, fees);

        // uint256 netCollateral = collateralAmount - fees;
        TransferHelper.safeTransfer(address(collateral), to, netCollateralToGetBack);

        uint256 usdlToBurn = Collateral2USDL(address(collateral), netCollateralToGetBack); 
        // uint256 usdlToBurn = collateralAmount * price[address(collateral)] / 1e18;
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






