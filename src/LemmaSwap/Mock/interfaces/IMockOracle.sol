pragma solidity ^0.7.6;
pragma abicoder v2;


interface IMockOracle {
    function getPriceNow(address baseToken, address quoteToken) view external returns (uint256);
    function setPriceNow(address baseToken, address quoteToken, uint256 price) external;
    function evolvePrice(address baseToken, address quoteToken) external;
    function setFreeze(address baseToken, address quoteToken, bool isFrozen) external;
}

