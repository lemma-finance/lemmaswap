// SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.10;

import {IUSDLemma} from "./interfaces/IUSDLemma.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {IWETH10} from "@weth10/interfaces/IWETH10.sol";
import {WETH10} from "@weth10/WETH10.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {LemmaSwap} from "./LemmaSwap/LemmaSwap.sol";



// NOTE: Needed for cheatcodes like `deal()` to get money
import "forge-std/Test.sol";


// import "forge-std/console.sol";

contract Collateral is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract Deployment is Test {
    IERC20 public wbtc;
    IUSDLemma public usdl;
    LemmaSwap public lemmaSwap;
    IWETH10 public weth;

    fallback() external payable {}
    receive() external payable {}

    struct s_testnet {
        address WETH;
        address WBTC;
        address USDC;
        address USDLemma;
    }

    // Take Addresses from 
    // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L36
    s_testnet public testnet_optimism_kovan;

    constructor() {
        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L45
        testnet_optimism_kovan.WETH = address(0x4200000000000000000000000000000000000006);

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L49
        testnet_optimism_kovan.WBTC = address(0xf69460072321ed663Ad8E69Bc15771A57D18522d);

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L41
        testnet_optimism_kovan.USDC = address(0x3e22e37Cb472c872B5dE121134cFD1B57Ef06560);

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L307
        testnet_optimism_kovan.USDLemma = address(0x15264ce29dEccc0C997D2Bd9D2accBBe37306517);

    }

    function deployTestnet(uint256 mode) external {
        s_testnet memory testnet = testnet_optimism_kovan;

        weth = IWETH10(testnet.WETH);
        TransferHelper.safeTransferETH(address(weth), 100e18);
        wbtc = IWETH10(testnet.WBTC);
        deal(address(wbtc), address(this), 10e25);

        usdl = IUSDLemma(testnet_optimism_kovan.USDLemma);

        lemmaSwap = new LemmaSwap(address(usdl), address(weth));
        lemmaSwap.setCollateralToDexIndex(address(weth), 0);
        lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);

        // lemmaSwap.setUSDL(address(usdl));

    }
    
    function askForMoney(address collateral, uint256 amount) external {
        TransferHelper.safeTransfer(collateral, msg.sender, amount);
    }
}


