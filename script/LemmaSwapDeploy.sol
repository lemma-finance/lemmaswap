// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {LemmaSwap} from "../src/LemmaSwap/LemmaSwap.sol";
import {FeesAccumulator} from "../src/LemmaSwap/FeesAccumulator.sol";
import {IXUSDL} from "../src/interfaces/IXUSDL.sol";
import {IUSDLemma} from "../src/interfaces/IUSDLemma.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract LemmaSwapDeployTestnet is Script {
    using stdJson for string;

    bytes32 public constant LEMMA_SWAP = keccak256("LEMMA_SWAP");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    struct LemmaPerpAddresses {
        address a_LemmaSynthBtc;
        address b_LemmaSynthEth;
        address c_optimismKovanUniV3Router;
        address d_settlementTokenManagerAddress;
        address e_usdc;
        address f_usdlCollateralWbtc;
        address g_usdlCollateralWeth;
        address h_usdLemmaAddress;
        address i_xLemmaSynthBtc;
        address j_xLemmaSynthEth;
        address k_xUSDLAddress;
        address l_feeAccumulator;
    }

    IUSDLemma usdLemma;
    LemmaSwap lemmaSwap;
    FeesAccumulator feesAccumulator;

    function run() external {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/src/test/fixtures/lemmaAddresses.script.json"
        );
        string memory json = vm.readFile(path);
        bytes memory addresses = json.parseRaw(".Addresses[1]");

        LemmaPerpAddresses memory lemmaPerpAddresses = abi.decode(
            addresses,
            (LemmaPerpAddresses)
        );

        vm.startBroadcast(tx.origin);
        usdLemma = IUSDLemma(lemmaPerpAddresses.h_usdLemmaAddress);
        lemmaSwap = new LemmaSwap(
            lemmaPerpAddresses.h_usdLemmaAddress,
            lemmaPerpAddresses.g_usdlCollateralWeth,
            lemmaPerpAddresses.l_feeAccumulator
        );
        console.log("lemmaSwap: ", address(lemmaSwap));

        // lemmaSwap = LemmaSwap(
        //     payable(0x6B283Cbcd24fdF67E1C4E23d28815C2607eEfE29)
        // );

        lemmaSwap.setCollateralToDexIndex(
            lemmaPerpAddresses.g_usdlCollateralWeth,
            0
        );
        lemmaSwap.setCollateralToDexIndex(
            lemmaPerpAddresses.f_usdlCollateralWbtc,
            0
        );

        usdLemma.grantRole(LEMMA_SWAP, address(lemmaSwap));

        feesAccumulator = new FeesAccumulator(
            lemmaPerpAddresses.c_optimismKovanUniV3Router,
            IXUSDL(lemmaPerpAddresses.k_xUSDLAddress)
        );

        feesAccumulator.setCollateralToDexIndexForUsdl(
            lemmaPerpAddresses.g_usdlCollateralWeth,
            0
        );
        feesAccumulator.setCollateralToDexIndexForUsdl(
            lemmaPerpAddresses.f_usdlCollateralWbtc,
            0
        );
        feesAccumulator.setCollateralToSynth(
            lemmaPerpAddresses.g_usdlCollateralWeth,
            lemmaPerpAddresses.b_LemmaSynthEth,
            lemmaPerpAddresses.j_xLemmaSynthEth
        );
        feesAccumulator.setCollateralToSynth(
            lemmaPerpAddresses.f_usdlCollateralWbtc,
            lemmaPerpAddresses.a_LemmaSynthBtc,
            lemmaPerpAddresses.i_xLemmaSynthBtc
        );
        vm.stopBroadcast();
    }
}
