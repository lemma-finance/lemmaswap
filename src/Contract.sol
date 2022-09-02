// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "../src/interfaces/IWETH9.sol";
import {IUSDLemma} from "./interfaces/IUSDLemma.sol";
import {IXUSDL} from "./interfaces/IXUSDL.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {LemmaSwap} from "./LemmaSwap/LemmaSwap.sol";
import {FeesAccumulator} from "./LemmaSwap/FeesAccumulator.sol";
import "forge-std/Test.sol";

contract Collateral is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract Bank is Test {
    function giveMoney(
        address token,
        address to,
        uint256 amount
    ) external {
        deal(token, to, amount);
    }
}

contract MockUniV3Router {
    ISwapRouter public router;
    uint256 public nextAmount;
    Bank bank;

    constructor(Bank _bank, address _router) {
        bank = _bank;
        router = ISwapRouter(_router);
    }

    function setRouter(address _router) external {
        router = ISwapRouter(_router);
    }

    function setNextSwapAmount(uint256 _amount) external {
        nextAmount = _amount;
    }

    function exactInputSingle(ISwapRouter.ExactInputSingleParams memory params)
        external
        returns (uint256)
    {
        if (address(router) != address(0)) {
            if (
                IERC20(params.tokenIn).allowance(
                    address(this),
                    address(router)
                ) != type(uint256).max
            ) {
                IERC20(params.tokenIn).approve(
                    address(router),
                    type(uint256).max
                );
            }
            // uint256 balanceBefore = IERC20(params.tokenOut).balanceOf(address(this));
            IERC20(params.tokenIn).transferFrom(
                msg.sender,
                address(this),
                params.amountIn
            );
            uint256 result = router.exactInputSingle(params);
            // uint256 balanceAfter = IERC20(params.tokenOut).balanceOf(address(this));
            // uint256 result = uint256(int256(balanceAfter) - int256(balanceBefore));

            // NOTE: This is not needed as the params.recipient field already identifies the right recipient appunto
            // IERC20(params.tokenOut).transfer(msg.sender, result);
            return result;
        } else {
            IERC20(params.tokenIn).transferFrom(
                msg.sender,
                address(this),
                params.amountIn
            );
            bank.giveMoney(
                params.tokenOut,
                address(params.recipient),
                nextAmount
            );
            return nextAmount;
        }
    }

    function exactOutputSingle(
        ISwapRouter.ExactOutputSingleParams memory params
    ) external returns (uint256) {
        if (address(router) != address(0)) {
            if (
                IERC20(params.tokenIn).allowance(
                    address(this),
                    address(router)
                ) != type(uint256).max
            ) {
                IERC20(params.tokenIn).approve(
                    address(router),
                    type(uint256).max
                );
            }
            bank.giveMoney(params.tokenIn, address(this), 1e40);
            uint256 balanceBefore = IERC20(params.tokenIn).balanceOf(
                address(this)
            );
            uint256 result = router.exactOutputSingle(params);
            uint256 balanceAfter = IERC20(params.tokenIn).balanceOf(
                address(this)
            );
            require(balanceBefore > balanceAfter, "exactOutputSingle T1");
            uint256 deltaBalance = uint256(
                int256(balanceBefore) - int256(balanceAfter)
            );
            require(deltaBalance <= params.amountInMaximum);
            // uint256 balanceBefore = IERC20(params.tokenOut).balanceOf(address(this));
            IERC20(params.tokenIn).transferFrom(
                msg.sender,
                address(this),
                deltaBalance
            );

            // uint256 balanceAfter = IERC20(params.tokenOut).balanceOf(address(this));
            // uint256 result = uint256(int256(balanceAfter) - int256(balanceBefore));

            // NOTE: This is not needed as the params.recipient field already identifies the right recipient appunto
            // IERC20(params.tokenOut).transfer(msg.sender, result);
            return result;
        } else {
            IERC20(params.tokenIn).transferFrom(
                msg.sender,
                address(this),
                nextAmount
            );
            bank.giveMoney(
                params.tokenOut,
                address(params.recipient),
                params.amountOut
            );
            return nextAmount;
        }
    }
}

contract Deployment is Test {
    IERC20 public wbtc;
    IUSDLemma public usdl;
    LemmaSwap public lemmaSwap;
    FeesAccumulator public feesAccumulator;
    IWETH9 public weth;
    MockUniV3Router public mockUniV3Router;
    address public admin;

    bytes32 public constant LEMMA_SWAP = keccak256("LEMMA_SWAP");
    bytes32 public constant FEES_TRANSFER_ROLE =
        keccak256("FEES_TRANSFER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    ISwapRouter public routerUniV3;
    Bank public bank = new Bank();

    fallback() external payable {}

    receive() external payable {}

    struct s_testnet {
        address WETH;
        address WBTC;
        address USDC;
        address USDLemma;
        address xusdl;
        address LemmaSynthEth;
        address LemmaSynthBtc;
        address xLemmaSynthEth;
        address xLemmaSynthBtc;
    }

    // Take Addresses from
    // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L36
    s_testnet public testnet_optimism_kovan;

    constructor() {
        routerUniV3 = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); // UniV3Router mainnet optimism - 0xE592427A0AEce92De3Edee1F18E0157C05861564
        mockUniV3Router = new MockUniV3Router(bank, address(routerUniV3));
        admin = 0x70Be17A1D2C66071c5ff4D31CF5e513E985aBcEE;
        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L45
        testnet_optimism_kovan.WETH = address(
            0x4200000000000000000000000000000000000006
        );

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L49
        testnet_optimism_kovan.WBTC = address(
            0xf69460072321ed663Ad8E69Bc15771A57D18522d
        );

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L41
        testnet_optimism_kovan.USDC = address(
            0x3e22e37Cb472c872B5dE121134cFD1B57Ef06560
        );

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L307
        // testnet_optimism_kovan.USDLemma = address(0xc34E7f18185b381d1d7aab8aeEC507e01f4276EE);
        testnet_optimism_kovan.USDLemma = address(
            0x3e193e134eF0f9187b07cbD6d0DBaD56E1B5542B
        );
        testnet_optimism_kovan.xusdl = address(
            0xB99f3c4fFc33E61aD1F060f9aF393b2f578dA6A4
        );

        // testnet_optimism_kovan.LemmaSynthEth = 0xac7b51F1D5Da49c64fAe5ef7D5Dc2869389A46FC;
        // testnet_optimism_kovan.LemmaSynthBtc = 0x72D43D1A52599289eDBE0c98342c6ED22eB85bd3;

        testnet_optimism_kovan
            .xLemmaSynthEth = 0xE920E05551b3718ae5B1f26d7462974FefdF77F3;
        testnet_optimism_kovan
            .xLemmaSynthBtc = 0x6b29B40D8583e5df5EE657345AAf62f18dEc2A1D;

        testnet_optimism_kovan
            .LemmaSynthEth = 0xE12d67F8529789988b153027366862AFa060D55c;
        testnet_optimism_kovan
            .LemmaSynthBtc = 0xD885FD5ACAD3eA15b6FCC7CEc4B638a8E030B24d;
    }

    function getAddresses() public view returns (s_testnet memory) {
        return testnet_optimism_kovan;
    }

    function deployTestnet(uint256 mode) external {
        s_testnet memory testnet = testnet_optimism_kovan;

        weth = IWETH9(testnet.WETH);
        TransferHelper.safeTransferETH(address(weth), 100e18);
        wbtc = IWETH9(testnet.WBTC);
        deal(address(wbtc), address(this), 1e8);

        usdl = IUSDLemma(testnet_optimism_kovan.USDLemma);

        lemmaSwap = new LemmaSwap(address(usdl), address(weth), admin);
        lemmaSwap.grantRole(OWNER_ROLE, address(this));
        lemmaSwap.setCollateralToDexIndex(address(weth), 0);
        lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);

        vm.startPrank(admin);
        usdl.grantRole(LEMMA_SWAP, address(lemmaSwap));
        vm.stopPrank();

        feesAccumulator = new FeesAccumulator(
            address(mockUniV3Router),
            IXUSDL(testnet_optimism_kovan.xusdl)
        );
        feesAccumulator.grantRole(OWNER_ROLE, address(this));

        feesAccumulator.setCollateralToDexIndexForUsdl(
            testnet_optimism_kovan.WETH,
            0
        );
        feesAccumulator.setCollateralToDexIndexForUsdl(
            testnet_optimism_kovan.WBTC,
            1
        );

        feesAccumulator.setCollateralToSynth(
            testnet_optimism_kovan.WETH,
            0xE12d67F8529789988b153027366862AFa060D55c,
            0xE920E05551b3718ae5B1f26d7462974FefdF77F3
        );
        feesAccumulator.setCollateralToSynth(
            testnet_optimism_kovan.WBTC,
            0xD885FD5ACAD3eA15b6FCC7CEc4B638a8E030B24d,
            0x6b29B40D8583e5df5EE657345AAf62f18dEc2A1D
        );
    }

    function askForMoney(address collateral, uint256 amount) external {
        TransferHelper.safeTransfer(collateral, msg.sender, amount);
    }

    function grantRole(address addr) external {
        vm.startPrank(admin);
        usdl.grantRole(LEMMA_SWAP, addr);
        vm.stopPrank();
    }
}
