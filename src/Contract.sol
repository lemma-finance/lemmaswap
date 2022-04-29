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

contract Deployment {
    MockOracle public oracle;
    MockPerp public perp;
    // Collateral public weth;
    IERC20 public wbtc;
    MockLemmaTreasury public lemmaTreasury;
    Quoter public quoter;
    MockUSDL public usdl;
    LemmaSwap public lemmaSwap;
    IWETH10 public weth;

    fallback() external payable {}
    receive() external payable {}

    struct s_testnet {
        address WETH;
        address USDLemma;
    }

    s_testnet public testnet_optimism_kovan;

    constructor() {
        testnet_optimism_kovan.WETH = address(0x4200000000000000000000000000000000000006);
        testnet_optimism_kovan.USDLemma = address(0x15264ce29dEccc0C997D2Bd9D2accBBe37306517);
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
        usdl = new MockUSDL(
            "USDL",
            "USDL",
            address(lemmaTreasury)
        );

        quoter = new Quoter();
        quoter.setUSDLemma(address(usdl));

        usdl.setPrice(address(weth), 100e18);
        usdl.setPrice(address(wbtc), 50e18);

        lemmaSwap = new LemmaSwap(address(usdl), address(weth), address(quoter));
        lemmaSwap.setCollateralToDexIndex(address(weth), 0);
        lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);

        usdl.setLemmaSwap(address(lemmaSwap));
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
        usdl = new MockUSDL(
            "USDL",
            "USDL",
            address(lemmaTreasury)
        );

        quoter = new Quoter();
        quoter.setUSDLemma(address(usdl));

        usdl.setPrice(address(weth), 100e18);
        usdl.setPrice(address(wbtc), 50e18);

        lemmaSwap = new LemmaSwap(address(usdl), address(weth), address(quoter));
        lemmaSwap.setCollateralToDexIndex(address(weth), 0);
        lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);

        usdl.setLemmaSwap(address(lemmaSwap));
    }

    function askForMoney(address collateral, uint256 amount) external {
        TransferHelper.safeTransfer(collateral, msg.sender, amount);
    }
}


