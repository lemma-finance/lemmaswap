pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Decimals} from "../interfaces/IERC20Decimals.sol";
import {IUSDLemma} from "../interfaces/IUSDLemma.sol";
import {IXUSDL} from "../interfaces/IXUSDL.sol";
import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import "../interfaces/ISwapRouter.sol";
import "forge-std/Test.sol";

contract FeesAccumulator is AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LEMMA_SWAP = keccak256("LEMMA_SWAP");
    bytes32 public constant FEES_TRANSFER_ROLE = keccak256("FEES_TRANSFER_ROLE");

    IUSDLemma public usdl;
    IXUSDL public xusdl;

    address public router;
    mapping(address => mapping(address => uint256)) public feesAccumulate;
    
    mapping(address => uint8) public collateralToDexIndexForUsdl;
    mapping(address => uint8) public collateralToDexIndexForSynth;

    struct SynthAddresses {
        address synthAddress;
        address xSynthAddress;
    }

    mapping(address => SynthAddresses) public synthMapping;

    event AddFees(address indexed feeTaker, address indexed feesToken, uint256 indexed fees);
    event SubFees(address indexed feeTaker, address indexed feesToken, uint256 indexed fees);

    modifier validCollateral(address collateral) {
        require(collateral != address(0), "!collateral");
        _;
    }

    constructor(address _router, IXUSDL _xusdl) public {
        require(_router != address(0), "!_router");
        router = _router;
        xusdl = _xusdl;
        usdl = IUSDLemma(address(xusdl.usdl()));
        _setRoleAdmin(LEMMA_SWAP, ADMIN_ROLE);
        _setRoleAdmin(FEES_TRANSFER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        // grantRole(LEMMA_SWAP, lemmaSwap);
        // grantRole(FEES_TRANSFER_ROLE, lemmaSwap);
    }

    function setRouter(address _router) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "!ADMIN_ROLE");
        require(_router != address(0), "!_router");
        router = _router;
    }

    /**
        @notice Updates the Collateral --> dexIndex association
        @dev The dexIndex is a low level detail that we won't to hide from the UX related methods 
    */
    function setCollateralToDexIndexForUsdl(address collateral, uint8 dexIndex)
        external
        // onlyOwner
        validCollateral(collateral)
    {
        collateralToDexIndexForUsdl[collateral] = dexIndex + 1;
    }

    /**
        @notice Updates the Collateral --> dexIndex association
        @dev The dexIndex is a low level detail that we won't to hide from the UX related methods 
    */
    function setCollateralToDexIndexForSynth(address collateral, uint8 dexIndex)
        external
        // onlyOwner
        validCollateral(collateral)
    {
        collateralToDexIndexForSynth[collateral] = dexIndex + 1;
    }

    function setCollateralToSynth(address collateral, address lemmaSynth, address xLemmaSynth)
        external
        // onlyOwner
        validCollateral(collateral)
    {
        synthMapping[collateral].synthAddress = lemmaSynth;
        synthMapping[collateral].xSynthAddress = xLemmaSynth;
    }

    /**
        @notice Collateral --> dexIndex
        @dev Currently it is assumed that there is 1:1 collateral <--> dexIndex relationship 
        @dev Since 0 is an invalid value, in the internal structure we need to record the values adding 1 to allow this 
     */
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

    function distibuteFees(address _token) external {
        require(hasRole(FEES_TRANSFER_ROLE, msg.sender), "!FEES_TRANSFER_ROLE");
        uint256 totalBalance = IERC20Decimals(_token).balanceOf(address(this));
        uint256 decimals = IERC20Decimals(_token).decimals();
        require(totalBalance > 0, "!totalBalance");
        IERC20Decimals(_token).approve(address(usdl), totalBalance/2);
        uint256 dexIndex = _convertCollateralToValidDexIndex(_token, true);
        uint256 collateralAmount = ((totalBalance / 2) * 1e18) / (10**decimals);
        usdl.depositToWExactCollateral(
            address(xusdl),
            collateralAmount,
            dexIndex,
            0,
            _token
        );

        uint256 synthAmount = totalBalance/2;
        collateralAmount = synthAmount;
        if (_token != usdl.perpSettlementToken()) {
            address[] memory _path = new address[](2);
            _path[0] = _token;
            _path[1] = usdl.perpSettlementToken();

            decimals = IERC20Decimals(usdl.perpSettlementToken()).decimals();
            IERC20Decimals(_token).approve(router, synthAmount);

            collateralAmount = _swapOnUniV3(router, _path, synthAmount);
        }
        collateralAmount = (collateralAmount * 1e18) / (10**decimals);

        SynthAddresses memory _sa = synthMapping[_token];
        IERC20Decimals(IERC20Decimals(usdl.perpSettlementToken())).approve(_sa.synthAddress, collateralAmount);
        ILemmaSynth(_sa.synthAddress).depositToWExactCollateral(
            address(_sa.xSynthAddress),
            collateralAmount,
            0,
            0,
            IERC20(usdl.perpSettlementToken())
        );
    }

    /// @dev Helper function to swap on UniV3
    function _swapOnUniV3(
        address router,
        address[] memory path,
        uint256 amount
    ) internal returns (uint256) {
        uint256 res;
        IERC20Decimals(path[0]).approve(router, type(uint256).max);
        ISwapRouter.ExactInputSingleParams memory temp = ISwapRouter.ExactInputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: 3000,
            recipient: address(this),
            deadline: type(uint256).max,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 balanceBefore = IERC20Decimals(path[1]).balanceOf(address(this));
        res = ISwapRouter(router).exactInputSingle(temp);
        uint256 balanceAfter = IERC20Decimals(path[1]).balanceOf(address(this));
        res = uint256(int256(balanceAfter) - int256(balanceBefore));
        IERC20Decimals(path[0]).approve(router, 0);
        return res;
    }
}

