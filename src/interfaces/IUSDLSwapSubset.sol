pragma solidity ^0.7.6;
pragma abicoder v2;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IUSDLSwapSubset is IERC20 {
    function depositToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 minUSDLToMint,
        IERC20 collateral
    ) external;

    function withdrawToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 maxUSDLToBurn,
        IERC20 collateral
    ) external;

    function depositTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 maxCollateralAmountRequired,
        IERC20 collateral,
        bool isLemmaSwap
    ) external;


    function withdrawTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 minCollateralAmountToGetBack,
        IERC20 collateral
    ) external;

    function USDL2Collateral(address collateral, uint256 amount) external view returns (uint256);
    function Collateral2USDL(address collateral, uint256 amount) external view returns (uint256);


    function lemmaTreasury() external view returns (address);
    function getFees(uint256 dexIndex, address collateral, bool isMinting) external view returns (uint256);
    function getTotalPosition(uint256 dexIndex, address collateral) external view returns (int256);
}




