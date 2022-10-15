// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IUSDLemma} from "../interfaces/IUSDLemma.sol";
import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import {IXUSDL} from "../interfaces/IXUSDL.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {LemmaSwapV2} from "../LemmaSwap/LemmaSwapV2.sol";
import {FeesAccumulator} from "../LemmaSwap/FeesAccumulator.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

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

contract MockSwapRouter is Test {
    function swap(
        address token,
        address to,
        uint256 amount
    ) public returns (uint256) {
        deal(token, to, amount);
        return amount;
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
    using stdJson for string;
    IERC20 public wbtc;
    IUSDLemma public usdl;
    ILemmaSynth public lemmaSynth;
    LemmaSwapV2 public lemmaSwap;
    FeesAccumulator public feesAccumulator;
    IWETH9 public weth;
    IERC20 public usdc;
    MockUniV3Router public mockUniV3Router;
    MockSwapRouter public mockSwapRouter;
    address public admin;

    bytes32 public constant LEMMA_SWAP = keccak256("LEMMA_SWAP");
    bytes32 public constant FEES_TRANSFER_ROLE =
        keccak256("FEES_TRANSFER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    ISwapRouter public routerUniV3;
    Bank public bank = new Bank();

    fallback() external payable {}

    receive() external payable {}

    struct LemmaAddresses {
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
    }

    struct PerpAddresses {
        address a_perpVault;
        address b_accountBalance;
        address c_admin;
    }

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
    LemmaAddresses public lemmaAddresses;
    PerpAddresses public perpAddresses;

    address public perpVault;
    address public accountBalance;
    uint256 public chainId;

    constructor() {
        chainId = block.chainid;

        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/src/test/fixtures/lemmaAddresses.test.json"
        );
        string memory json = vm.readFile(path);

        bytes memory _lemmaAddresses;
        bytes memory _perpAddresses;

        if (chainId == 69) {
            _lemmaAddresses = json.parseRaw(".Addresses[0][0]");
            _perpAddresses = json.parseRaw(".Addresses[0][1]");
        } else {
            _lemmaAddresses = json.parseRaw(".Addresses[1][0]");
            _perpAddresses = json.parseRaw(".Addresses[1][1]");
        }

        lemmaAddresses = abi.decode(_lemmaAddresses, (LemmaAddresses));
        perpAddresses = abi.decode(_perpAddresses, (PerpAddresses));

        perpVault = perpAddresses.a_perpVault;
        accountBalance = perpAddresses.b_accountBalance;
        routerUniV3 = ISwapRouter(lemmaAddresses.c_optimismKovanUniV3Router); // UniV3Router mainnet optimism - 0xE592427A0AEce92De3Edee1F18E0157C05861564
        mockUniV3Router = new MockUniV3Router(bank, address(routerUniV3));
        mockSwapRouter = new MockSwapRouter();
        admin = perpAddresses.c_admin;
        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L45
        testnet_optimism_kovan.WETH = address(
            lemmaAddresses.g_usdlCollateralWeth
        );

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L49
        testnet_optimism_kovan.WBTC = address(
            lemmaAddresses.f_usdlCollateralWbtc
        );

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L41
        testnet_optimism_kovan.USDC = address(lemmaAddresses.e_usdc);

        // https://github.com/lemma-finance/scripts/blob/312f7c9f45186610e98396693c81a26ead9e0a6e/config.json#L307
        // testnet_optimism_kovan.USDLemma = address(0xc34E7f18185b381d1d7aab8aeEC507e01f4276EE);
        testnet_optimism_kovan.USDLemma = address(
            lemmaAddresses.h_usdLemmaAddress
        );
        testnet_optimism_kovan.xusdl = address(lemmaAddresses.k_xUSDLAddress);

        // testnet_optimism_kovan.LemmaSynthEth = 0xac7b51F1D5Da49c64fAe5ef7D5Dc2869389A46FC;
        // testnet_optimism_kovan.LemmaSynthBtc = 0x72D43D1A52599289eDBE0c98342c6ED22eB85bd3;

        testnet_optimism_kovan.xLemmaSynthEth = lemmaAddresses.j_xLemmaSynthEth;
        testnet_optimism_kovan.xLemmaSynthBtc = lemmaAddresses.i_xLemmaSynthBtc;

        testnet_optimism_kovan.LemmaSynthEth = lemmaAddresses.b_LemmaSynthEth;
        testnet_optimism_kovan.LemmaSynthBtc = lemmaAddresses.a_LemmaSynthBtc;
    }

    function getAddresses() public view returns (s_testnet memory) {
        return testnet_optimism_kovan;
    }

    function deployTestnet(uint256 mode) external {
        s_testnet memory testnet = testnet_optimism_kovan;

        usdc = IERC20(testnet_optimism_kovan.USDC);
        weth = IWETH9(testnet.WETH);
        TransferHelper.safeTransferETH(address(weth), 100e18);
        wbtc = IWETH9(testnet.WBTC);
        deal(address(wbtc), address(this), 1e8);

        usdl = IUSDLemma(testnet_optimism_kovan.USDLemma);
        lemmaSynth = ILemmaSynth(testnet_optimism_kovan.LemmaSynthEth);

        lemmaSwap = new LemmaSwapV2(address(usdl), address(weth), admin);
        lemmaSwap.grantRole(OWNER_ROLE, address(this));

        if (chainId == 69) {
            lemmaSwap.setCollateralToDexIndex(address(weth), 0);
            lemmaSwap.setCollateralToDexIndex(address(wbtc), 1);
        } else {
            lemmaSwap.setCollateralToDexIndex(address(weth), 0);
            lemmaSwap.setCollateralToDexIndex(address(wbtc), 0);
        }

        vm.startPrank(admin);
        usdl.grantRole(LEMMA_SWAP, address(lemmaSwap));
        vm.stopPrank();

        feesAccumulator = new FeesAccumulator(
            address(mockSwapRouter),
            IXUSDL(testnet_optimism_kovan.xusdl)
        );
        feesAccumulator.grantRole(OWNER_ROLE, address(this));

        feesAccumulator.setCollateralToDexIndexForUsdl(
            testnet_optimism_kovan.WETH,
            0
        );
        feesAccumulator.setCollateralToDexIndexForUsdl(
            testnet_optimism_kovan.WBTC,
            0
        );

        feesAccumulator.setCollateralToSynth(
            testnet_optimism_kovan.WETH,
            testnet_optimism_kovan.LemmaSynthEth,
            testnet_optimism_kovan.xLemmaSynthEth
        );
        feesAccumulator.setCollateralToSynth(
            testnet_optimism_kovan.WBTC,
            testnet_optimism_kovan.LemmaSynthBtc,
            testnet_optimism_kovan.xLemmaSynthBtc
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
