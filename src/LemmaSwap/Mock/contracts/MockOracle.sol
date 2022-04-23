pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import {IERC20} from '@weth10/interfaces/IERC20.sol';
// import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "forge-std/console.sol";

contract MockOracle {
    // Price is 1e18 format
    // base --> quote --> price
    mapping( address => mapping(address => uint256) ) public prices;

    mapping ( address => mapping(address => bool) ) public isFrozen;

    function evolvePrice(address baseToken, address quoteToken) public {
        if(! isFrozen[baseToken][quoteToken] ) {
            // Simple logic: price increasing 1% 
            prices[baseToken][quoteToken] += prices[baseToken][quoteToken] / 100;
        }
    }

    function getPriceNow(address baseToken, address quoteToken) view external returns (uint256) {
        return prices[baseToken][quoteToken];
    }

    function setPriceNow(address baseToken, address quoteToken, uint256 price) external {
        prices[baseToken][quoteToken] = price;
    }

    function setFreeze(address baseToken, address quoteToken, bool _isFrozen) external {
        isFrozen[baseToken][quoteToken] = _isFrozen;
    }

}




