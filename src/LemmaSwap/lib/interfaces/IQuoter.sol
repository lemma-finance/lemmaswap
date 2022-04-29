pragma solidity ^0.7.6;
// pragma abicoder v2;



interface IQuoter {
    function setMode(uint256 _mode) external;
    function USDL2Collateral(address collateral, uint256 amount) external returns (uint256); 
    function Collateral2USDL(address collateral, uint256 amount) external returns (uint256); 
}

