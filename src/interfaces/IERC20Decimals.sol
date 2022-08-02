pragma solidity ^0.7.6;

import {IERC20} from '@weth10/interfaces/IERC20.sol';

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint256);
}
