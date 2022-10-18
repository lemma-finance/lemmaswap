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

    constructor(address _router, IXUSDL _xusdl) {
        require(_router != address(0), "!_router");
        router = _router;
        xusdl = _xusdl;
        usdl = IUSDLemma(address(xusdl.usdl()));
        _setRoleAdmin(OWNER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(FEES_TRANSFER_ROLE, OWNER_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        grantRole(OWNER_ROLE, msg.sender);
    }

    /// @notice setRouter will set swapping router
    function setRouter(address _router) external onlyRole(OWNER_ROLE) {
        require(_router != address(0), "!_router");
        router = _router;
    }

    ///@notice setFeeTransfererRole will assign FEES_TRANSFER_ROLE to _feeTransferer address
    function setFeeTransfererRole(address _feeTransferer)
        external
        onlyRole(OWNER_ROLE)
    {
        require(_feeTransferer != address(0), "!zero address");
        grantRole(FEES_TRANSFER_ROLE, _feeTransferer);
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
    /// @param _swapData swap data to do the actual swap
    function distibuteFees(address _token, bytes calldata _swapData)
        external
        onlyRole(FEES_TRANSFER_ROLE)
    {
        uint256 totalBalance = IERC20Decimals(_token).balanceOf(address(this));
        if (_token == address(usdl)) {
            usdl.transfer(address(xusdl), totalBalance);
            return;
        }
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
        address settlmentToken = usdl.perpSettlementToken();
        uint256 synthAmount = totalBalance - (totalBalance / 2);
        collateralAmount = synthAmount;
        if (_token != settlmentToken) {
            address _tokenOut = settlmentToken;

            decimals = IERC20Decimals(settlmentToken).decimals();
            IERC20Decimals(_token).approve(router, synthAmount);

            collateralAmount = _swap(router, _tokenOut, _swapData);
        }

        SynthAddresses memory _sa = synthMapping[_token];
        IERC20Decimals(IERC20Decimals(settlmentToken)).approve(
            _sa.synthAddress,
            collateralAmount
        );

        collateralAmount = (collateralAmount * 1e18) / (10**decimals);

        ILemmaSynth(_sa.synthAddress).depositToWExactCollateral(
            address(_sa.xSynthAddress),
            collateralAmount,
            0,
            0,
            IERC20(settlmentToken)
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
    function _swap(
        address _router,
        address _tokenOut,
        bytes calldata _swapData
    ) internal returns (uint256 res) {
        uint256 balanceBefore = IERC20Decimals(_tokenOut).balanceOf(
            address(this)
        );
        _router.call(_swapData);
        uint256 balanceAfter = IERC20Decimals(_tokenOut).balanceOf(
            address(this)
        );
        res = uint256(int256(balanceAfter) - int256(balanceBefore));
    }
}
