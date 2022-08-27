// SPDX-License-Identifier: UNLICENSED
// pragma solidity >=0.6.0 <0.9.0;
pragma solidity ^0.7.6;
pragma abicoder v2;

import {LemmaSwap} from "../src/LemmaSwap/LemmaSwap.sol";
import {FeesAccumulator} from "../src/LemmaSwap/FeesAccumulator.sol";
import {IXUSDL} from "../src/interfaces/IXUSDL.sol";
import {IUSDLSwapSubset} from "../src/interfaces/IUSDLSwapSubset.sol";
import "forge-std/Script.sol";

contract LemmaSwapDeployTestnet is Script {

    bytes32 public constant LEMMA_SWAP = keccak256("LEMMA_SWAP");

    address usdlCollateralWeth = 0x4200000000000000000000000000000000000006; //WETH
    address usdlCollateralWbtc = 0xf69460072321ed663Ad8E69Bc15771A57D18522d; //WBTC
    address usdc = 0x3e22e37Cb472c872B5dE121134cFD1B57Ef06560;
    address usdLemmaAddress = 0xc34E7f18185b381d1d7aab8aeEC507e01f4276EE;
    address xUSDLAddress = 0xB99f3c4fFc33E61aD1F060f9aF393b2f578dA6A4;
    address settlementTokenManagerAddress = 0x790f5ea61193Eb680F82dE61230863c12f8AC5cC;

    address xLemmaSynthEth = 0xE920E05551b3718ae5B1f26d7462974FefdF77F3;
    address xLemmaSynthBtc = 0x6b29B40D8583e5df5EE657345AAf62f18dEc2A1D;

    address LemmaSynthEth = 0xE12d67F8529789988b153027366862AFa060D55c;
    address LemmaSynthBtc = 0xD885FD5ACAD3eA15b6FCC7CEc4B638a8E030B24d;

    address optimismKovanUniV3Router = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45; // Optimism Kovan 

    IUSDLSwapSubset usdLemma;
    LemmaSwap lemmaSwap;
    FeesAccumulator feesAccumulator;

    function run() external {
        vm.startBroadcast(tx.origin);
        usdLemma = IUSDLSwapSubset(usdLemmaAddress);
        lemmaSwap = new LemmaSwap(usdLemmaAddress, usdlCollateralWeth, msg.sender);
        lemmaSwap.setCollateralToDexIndex(usdlCollateralWeth, 0);
        lemmaSwap.setCollateralToDexIndex(usdlCollateralWbtc, 1);
        usdLemma.grantRole(LEMMA_SWAP, address(lemmaSwap));
        console.log('lemmaSwap: ', address(lemmaSwap));

        feesAccumulator = new FeesAccumulator(optimismKovanUniV3Router, IXUSDL(xUSDLAddress));

        feesAccumulator.setCollateralToDexIndexForUsdl(usdlCollateralWeth, 0);
        feesAccumulator.setCollateralToDexIndexForUsdl(usdlCollateralWbtc, 1);
        feesAccumulator.setCollateralToSynth(usdlCollateralWeth, LemmaSynthEth, xLemmaSynthEth);
        feesAccumulator.setCollateralToSynth(usdlCollateralWbtc, LemmaSynthBtc, xLemmaSynthBtc);
        vm.stopBroadcast();
    }
}
