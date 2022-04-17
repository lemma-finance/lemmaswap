pragma solidity ^0.7.6;

interface IPermit {
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function nonces(address owner) external view returns (uint);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}
