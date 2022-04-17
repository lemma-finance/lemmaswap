pragma solidity ^0.7.6;
pragma abicoder v2;


interface IMockPerp {
    function openShort1XWExactCollateral(address collateral, uint256 amount) external returns(uint256); 
    function closeShort1XWExactCollateral(address collateral, uint256 amount) external returns(uint256);
}

