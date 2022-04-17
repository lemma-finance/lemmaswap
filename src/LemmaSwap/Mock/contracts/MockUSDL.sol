pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "./interfaces/IUSDLMock.sol";
import "./interfaces/IPermit.sol";
import "./interfaces/ILemmaRouter.sol";
import "forge-std/console.sol";


contract MockLemmaTreasury {}



contract USDLMock {

    address public lemmaTreasury;

    event Deposited(address, address, uint256, uint256, uint256);
    event Withdrawn(address, address, uint256, uint256, uint256);


    constructor(address _mockLemmaTreasury) {
        lemmaTreasury = _mockLemmaTreasury;
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
        
    }

    function withdrawToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 maxUSDLToBurn,
        IERC20 collateral
    ) external {

    }

    // function lemmaTreasury() external view returns (address) {
    //     return 0;
    // }

    function getFees(uint256 dexIndex, address collateral, bool isMinting) external view returns (uint256) {
        return 0;
    }

    function getTotalPosition(uint256 dexIndex, address collateral) external view returns (int256) {
        return 0;
    }

}






