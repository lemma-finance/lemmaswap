// SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.10;

import {MockOracle} from "./LemmaSwap/Mock/contracts/MockOracle.sol";
import {IMockOracle} from "./LemmaSwap/Mock/interfaces/IMockOracle.sol";
import {MockPerp} from "./LemmaSwap/Mock/contracts/MockPerp.sol";
import {MockLemmaTreasury, MockUSDL} from "./LemmaSwap/Mock/contracts/MockUSDL.sol";
import {Denominations} from "./LemmaSwap/Mock/libs/Denominations.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
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
    Collateral public collateral;
    MockLemmaTreasury public lemmaTreasury;
    MockUSDL public usdl;
    
    constructor() {
        collateral = new Collateral("WETH", "WETH", 100e18);
        oracle = new MockOracle();
        oracle.setPriceNow(address(collateral), Denominations.USD, 100);

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
    }

    function askForMoney(address collateral, uint256 amount) external {
        TransferHelper.safeTransfer(collateral, msg.sender, amount);
    }
}


