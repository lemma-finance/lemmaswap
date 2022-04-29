pragma solidity ^0.7.6;
// pragma abicoder v2;

import {IQuoter} from "./interfaces/IQuoter.sol";
import "forge-std/console.sol";




interface IUSDLemmaForPrice {
    function USDL2Collateral(address collateral, uint256 amount) external view returns (uint256);
    function Collateral2USDL(address collateral, uint256 amount) external view returns (uint256);
}

contract LocalQuoter is IQuoter {
    // Converts USDL amount to Collateral amount at oracle price

    IUSDLemmaForPrice public usdl;

    function setUSDLemma(address _usdl) external {
        usdl = IUSDLemmaForPrice(_usdl);
    }
    
    function USDL2Collateral(address collateral, uint256 amount) external override returns (uint256) {
        usdl.USDL2Collateral(collateral, amount);
    }

    function Collateral2USDL(address collateral, uint256 amount) external override returns (uint256) { 
        usdl.Collateral2USDL(collateral, amount);
    }
}

