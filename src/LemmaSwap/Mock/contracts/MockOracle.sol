pragma solidity ^0.7.6;
pragma abicoder v2;

import {Multicall} from '@uniswap/v3-periphery/contracts/base/Multicall.sol';
import {IWETH9} from '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "forge-std/console.sol";

contract MockOracle {
    // base --> quote --> price
    mapping( address => mapping(address => uint256) ) public prices;

    mapping ( address => mapping(address => bool) ) public isFrozen;

    constructor() {
        state = 100;
        isFrozen = false;
    }

    function evolvePrice(address baseToken, address quoteToken) public {
        prices[baseToken][quoteToken] += 1;
    }

    function getPriceNow(address baseToken, address quoteToken) external returns (uint256) {
        if (! isFrozen[baseToken][quoteToken]) {
            evolvePrice(baseToken, quoteToken);
        }

        return prices[baseToken][quoteToken];
    }

    function setPriceNow(address baseToken, address quoteToken, uint256 price) external {
        prices[baseToken][quoteToken] = price;
    }

    function setFreeze(address baseToken, address quoteToken, bool _isFrozen) external {
        isFrozen[baseToken][quoteToken] = _isFrozen;
    }

}




