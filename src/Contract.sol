// SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.10;

import {MockOracle} from "./LemmaSwap/Mock/contracts/MockOracle.sol";
import {IMockOracle} from "./LemmaSwap/Mock/interfaces/IMockOracle.sol";
import {MockPerp} from "./LemmaSwap/Mock/contracts/MockPerp.sol";
import {MockLemmaTreasury, MockUSDL} from "./LemmaSwap/Mock/contracts/MockUSDL.sol";
import {Denominations} from "./LemmaSwap/Mock/libs/Denominations.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {LemmaSwap} from "./LemmaSwap/LemmaSwap.sol";
// import {ERC20} from "solmate/tokens/ERC20.sol";

contract Collateral is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract Deployment {
    MockOracle public oracle;
    MockPerp public perp;
    Collateral public weth;
    Collateral public wbtc;
    MockLemmaTreasury public lemmaTreasury;
    MockUSDL public usdl;
    LemmaSwap public lemmaSwap;
    
    constructor() {
        weth = new Collateral("WETH", "WETH", 100e18);
        wbtc = new Collateral("WBTC", "WBTC", 100e18);
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

        usdl.setPrice(address(weth), 100e18);
        usdl.setPrice(address(wbtc), 50e18);

        lemmaSwap = new LemmaSwap(address(usdl));
        lemmaSwap.setCollateralToDexIndex(address(weth), 0);
        lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);
    }

    function askForMoney(address collateral, uint256 amount) external {
        TransferHelper.safeTransfer(collateral, msg.sender, amount);
    }
}


