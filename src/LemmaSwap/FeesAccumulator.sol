// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";
import {IUSDLemma} from "../interfaces/IUSDLemma.sol";
import {IXUSDL} from "../interfaces/IXUSDL.sol";
import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

contract FeesAccumulator is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant FEES_TRANSFER_ROLE =
        keccak256("FEES_TRANSFER_ROLE");

    IUSDLemma public usdl;
    IXUSDL public xusdl;
    address public router;

    struct SynthAddresses {
        address synthAddress;
        address xSynthAddress;
    }

    mapping(address => SynthAddresses) public synthMapping;
    mapping(address => mapping(address => uint256)) public feesAccumulate;
    mapping(address => uint8) public collateralToDexIndexForUsdl;
    mapping(address => uint8) public collateralToDexIndexForSynth;

    modifier validCollateral(address collateral) {
        require(collateral != address(0), "!collateral");
        _;
    }

    constructor(address _router, IXUSDL _xusdl) public {
        require(_router != address(0), "!_router");
        router = _router;
        xusdl = _xusdl;
        usdl = IUSDLemma(address(xusdl.usdl()));
        _setRoleAdmin(OWNER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(FEES_TRANSFER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        grantRole(OWNER_ROLE, msg.sender);
    }

    /// @notice setRouter will set swapping router
    function setRouter(address _router) external onlyRole(OWNER_ROLE) {
        require(_router != address(0), "!_router");
        router = _router;
    }

    /// @notice Updates the Collateral --> dexIndex association as per USDLemma Contract
    /// @dev The dexIndex is a low level detail that we won't to hide from the UX related methods
    function setCollateralToDexIndexForUsdl(address collateral, uint8 dexIndex)
        external
        onlyRole(OWNER_ROLE)
        validCollateral(collateral)
    {
        collateralToDexIndexForUsdl[collateral] = dexIndex + 1;
    }

    /// @notice Updates the Collateral --> dexIndex association as per LemmaSynth Contract
    /// @dev The dexIndex is a low level detail that we won't to hide from the UX related methods
    function setCollateralToDexIndexForSynth(address collateral, uint8 dexIndex)
        external
        onlyRole(OWNER_ROLE)
        validCollateral(collateral)
    {
        collateralToDexIndexForSynth[collateral] = dexIndex + 1;
    }

    /// @notice set LemmaSynth and xLemmaSynth address for collateral
    function setCollateralToSynth(
        address collateral,
        address lemmaSynth,
        address xLemmaSynth
    ) external onlyRole(OWNER_ROLE) validCollateral(collateral) {
        synthMapping[collateral].synthAddress = lemmaSynth;
        synthMapping[collateral].xSynthAddress = xLemmaSynth;
    }

    /// @notice distibuteFees function will distribute fees of any token between xUsdl and xLemmaSynth contract address
    /// @param _token erc20 tokenAddress to tranfer as a gees betwwn xUsdl and xLemmaSynth
    /// @param _swapFee is a feeTier(e.g. 3000) will use to swap _token to USDC
    /// @param _swapMinAmount minAmount need to get if swap happens
    function distibuteFees(
        address _token,
        uint24 _swapFee,
        uint256 _swapMinAmount
    ) external onlyRole(FEES_TRANSFER_ROLE) {
        uint256 totalBalance = IERC20Decimals(_token).balanceOf(address(this));
        uint256 decimals = IERC20Decimals(_token).decimals();
        require(totalBalance > 0, "!totalBalance");
        IERC20Decimals(_token).approve(address(usdl), totalBalance / 2);
        uint256 dexIndex = _convertCollateralToValidDexIndex(_token, true);
        uint256 collateralAmount = ((totalBalance / 2) * 1e18) / (10**decimals);
        usdl.depositToWExactCollateral(
            address(xusdl),
            collateralAmount,
            dexIndex,
            0,
            IERC20(_token)
        );

        uint256 synthAmount = totalBalance / 2;
        collateralAmount = synthAmount;
        if (_token != usdl.perpSettlementToken()) {
            address[] memory _path = new address[](2);
            _path[0] = _token;
            _path[1] = usdl.perpSettlementToken();

            decimals = IERC20Decimals(usdl.perpSettlementToken()).decimals();
            IERC20Decimals(_token).approve(router, synthAmount);

            collateralAmount = _swapOnUniV3(
                router,
                _path,
                synthAmount,
                _swapFee,
                _swapMinAmount
            );
        }
        collateralAmount = (collateralAmount * 1e18) / (10**decimals);

        SynthAddresses memory _sa = synthMapping[_token];
        IERC20Decimals(IERC20Decimals(usdl.perpSettlementToken())).approve(
            _sa.synthAddress,
            collateralAmount
        );
        ILemmaSynth(_sa.synthAddress).depositToWExactCollateral(
            address(_sa.xSynthAddress),
            collateralAmount,
            0,
            0,
            IERC20(usdl.perpSettlementToken())
        );
    }

    /// @notice Collateral --> dexIndex
    /// @dev Currently it is assumed that there is 1:1 collateral <--> dexIndex relationship
    /// @dev Since 0 is an invalid value, in the internal structure we need to record the values adding 1 to allow this
    function _convertCollateralToValidDexIndex(address collateral, bool isUsdl)
        internal
        view
        returns (uint256)
    {
        require(collateral != address(0), "!collateral");
        if (isUsdl) {
            require(
                collateralToDexIndexForUsdl[collateral] != 0,
                "Collateral not supported for usdl"
            );
            return collateralToDexIndexForUsdl[collateral] - 1;
        } else {
            require(
                collateralToDexIndexForSynth[collateral] != 0,
                "Collateral not supported for synth"
            );
            return collateralToDexIndexForSynth[collateral] - 1;
        }
    }

    /// @dev Helper function to swap on UniV3
    function _swapOnUniV3(
        address _router,
        address[] memory path,
        uint256 amount,
        uint24 _swapFee,
        uint256 _swapMinAmount
    ) internal returns (uint256) {
        uint256 res;
        IERC20Decimals(path[0]).approve(_router, type(uint256).max);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: path[0],
                tokenOut: path[1],
                fee: _swapFee,
                recipient: address(this),
                deadline: type(uint256).max,
                amountIn: amount,
                amountOutMinimum: _swapMinAmount,
                sqrtPriceLimitX96: 0
            });
        uint256 balanceBefore = IERC20Decimals(path[1]).balanceOf(
            address(this)
        );
        res = ISwapRouter(_router).exactInputSingle(params);
        uint256 balanceAfter = IERC20Decimals(path[1]).balanceOf(address(this));
        res = uint256(int256(balanceAfter) - int256(balanceBefore));
        IERC20Decimals(path[0]).approve(_router, 0);
        return res;
    }
}
