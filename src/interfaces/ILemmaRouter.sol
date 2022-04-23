pragma solidity ^0.7.6;
pragma abicoder v2;
import {IERC20} from '@weth10/interfaces/IERC20.sol';
// import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

    struct sEW {
        uint8 ewId;
        uint8 dexRouterId;
        // address swapActions;
        // bytes swapDatas;
    }

    struct sGet {
        uint8 v;                            // For Permit, leave 0 if not used 
        bytes32[] rs;                       // For Permit, leave [] if not used
    }

    struct sToken {
        IERC20 token;           // Token 
        uint256 amount;         // Max, Min, Exact amount of that token depending on the context
    }

    struct sInputToken {
        address from;                       // Token Source
        IERC20 token;                       // Token 
        uint256 maxTokenAmount;             // Max Input Token, used for Permit and token -> swap slippage control 
        uint8 v;                            // For Permit, leave 0 if not used 
        bytes32[] rs;                // For Permit, leave [] if not used
    }


    struct sSwap {
        uint8 ewId;
        uint8 dexRouterId;
        address swapActions;
        bytes swapDatas;
    }


    struct sMint {
        sGet source;                        // Input token source, for the permit pattern 
        sToken tokenIn;                     // Input token for the minting / staking process, it gets overridden when ETH is passed  
        sSwap swapInToCollateral;           // For minting only, defines how to swap the input token into a collateral that is supported by the `dexIndex` specified 
        sToken collateral;                  // For minting only, defines the collateral that is supported by the `dexIndex` specified. It could in theory be automatically detected as this information is static and can be associated to the `dexIndex` when it is created.
    }

    struct sRedeemUSDL {
        sToken collateral;                  // Collateral and the related min amount 
        sSwap swapColletaralToOut;          // Swap Out to Collateral
        sToken tokenOut;                    // Output Token
    }

interface ILemmaRouter {
    function mintAndStakeWExactCollateral(
        bool stake,
        sMint memory sm,
        address to,
        uint256 usdlAmount,
        uint256 dexIndex
    ) external payable;

    function unstakeAndRedeemWExactCollateral(
        bool unstake,
        sGet memory sg,
        sRedeemUSDL memory sr,
        address to,
        uint256 maxUSDLAmount,
        uint256 dexIndex
    ) external;

}



