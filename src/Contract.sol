// SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.10;

import {MockOracle} from "./LemmaSwap/Mock/contracts/MockOracle.sol";
import {IMockOracle} from "./LemmaSwap/Mock/interfaces/IMockOracle.sol";
import {MockPerp} from "./LemmaSwap/Mock/contracts/MockPerp.sol";
import {MockLemmaTreasury, MockUSDL} from "./LemmaSwap/Mock/contracts/MockUSDL.sol";
import {Quoter} from "./LemmaSwap/lib/Quoter.sol";
import {IUSDLemma} from "./interfaces/IUSDLemma.sol";
import {Denominations} from "./LemmaSwap/Mock/libs/Denominations.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from '@weth10/interfaces/IERC20.sol';
import {IWETH10} from "@weth10/interfaces/IWETH10.sol";
import {WETH10} from "@weth10/WETH10.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {LemmaSwap} from "./LemmaSwap/LemmaSwap.sol";
// import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/Test.sol";

import "forge-std/console.sol";

contract Collateral is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

// contract MyWETH is WETH10 {
//     constructor(uint256 initialSupply) WETH10() {
//         balanceOf[msg.sender] += initialSupply;
//     }
// }

contract Deployment is Test {
    MockOracle public oracle;
    MockPerp public perp;
    // Collateral public weth;
    IERC20 public wbtc;
    MockLemmaTreasury public lemmaTreasury;
    Quoter public quoter;
    IUSDLemma public usdl;
    LemmaSwap public lemmaSwap;
    IWETH10 public weth;

    bool useRealUSDL;

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


        useRealUSDL = true;
    }


    function _deployUSDL(bool useRealUSDL, address lemmaSwap) internal {
        if(useRealUSDL) {
            // Use Real USDL
            quoter.setMode(1);
            usdl = IUSDLemma(testnet_optimism_kovan.USDLemma);
        } else {
            MockUSDL _usdl = new MockUSDL(
                "USDL",
                "USDL",
                address(lemmaTreasury)
            );

            _usdl.setPrice(address(weth), 100e18);
            _usdl.setPrice(address(wbtc), 50e18);

            _usdl.setLemmaSwap(lemmaSwap);

            usdl = IUSDLemma(address(_usdl));
        }
    }


    function deployTestnet(uint256 mode) external {
        s_testnet memory testnet;

        if(mode == 1) {
            testnet = testnet_optimism_kovan;
        }
        weth = IWETH10(testnet.WETH);
        TransferHelper.safeTransferETH(address(weth), 100e18);
        // weth.deposit{value: 100e18}();
        // console.log("[deployTestnet()] WETH Balance = ", weth.balanceOf(address(this)));
        // weth = IWETH10(address(new MyWETH(100e18)));
        wbtc = IWETH10(testnet.WBTC);
        deal(address(wbtc), address(this), 10e25);
        // oracle = new MockOracle();
        // oracle.setPriceNow(address(weth), Denominations.USD, 100e18);
        // oracle.setPriceNow(address(wbtc), Denominations.USD, 120e18);

        // perp = new MockPerp(
        //     IMockOracle(address(oracle)),
        //     1000,   // feeOpenShort = 0.1% 
        //     1000    // feeCloseShort = 0.1%
        // );

        lemmaTreasury = new MockLemmaTreasury();

        quoter = new Quoter();
        quoter.setUSDLemma(address(usdl));

        lemmaSwap = new LemmaSwap(address(0), address(weth), address(quoter));
        lemmaSwap.setCollateralToDexIndex(address(weth), 0);
        lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);

        _deployUSDL(useRealUSDL, address(lemmaSwap));
        lemmaSwap.setUSDL(address(usdl));

    }
    
    function deployLocal() external {
        // weth = new Collateral("WETH", "WETH", 100e18);
        weth = new WETH10();
        // TransferHelper.safeTransferETH(address(weth), 10e18);
        weth.deposit{value: 100e18}();
        // weth = IWETH10(address(new MyWETH(100e18)));
        wbtc = IERC20(address(new Collateral("WBTC", "WBTC", 100e18)));
        oracle = new MockOracle();
        oracle.setPriceNow(address(weth), Denominations.USD, 100e18);
        oracle.setPriceNow(address(wbtc), Denominations.USD, 120e18);

        perp = new MockPerp(
            IMockOracle(address(oracle)),
            1000,   // feeOpenShort = 0.1% 
            1000    // feeCloseShort = 0.1%
        );

        lemmaTreasury = new MockLemmaTreasury();

        // usdl = new MockUSDL(
        //     "USDL",
        //     "USDL",
        //     address(lemmaTreasury)
        // );

        // usdl.setPrice(address(weth), 100e18);
        // usdl.setPrice(address(wbtc), 50e18);

        quoter = new Quoter();
        quoter.setUSDLemma(address(usdl));

        lemmaSwap = new LemmaSwap(address(0), address(weth), address(quoter));
        lemmaSwap.setCollateralToDexIndex(address(weth), 0);
        lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);

        _deployUSDL(useRealUSDL, address(lemmaSwap));
        lemmaSwap.setUSDL(address(usdl));
    }

    function askForMoney(address collateral, uint256 amount) external {
        TransferHelper.safeTransfer(collateral, msg.sender, amount);
    }
}


