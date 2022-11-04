// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Decimals, IERC20} from "../interfaces/IERC20Decimals.sol";
import {IUSDLemma} from "../interfaces/IUSDLemma.sol";
import {IXUSDL} from "../interfaces/IXUSDL.sol";
import {ILemmaSynth} from "../interfaces/ILemmaSynth.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

import "forge-std/Test.sol";

interface IUSDLemmaAdditional {
    function getIndexPrice(uint256 dexIndex, address collateral) external view returns (uint256);
}

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

    struct Amount {
        uint256 amount;
        uint256 decimals;
    }

    function convertDecimals(Amount memory x, uint8 decimals) internal pure returns(Amount memory) {
        return Amount({
            amount: x.amount * 10**(decimals) / 10**x.decimals,
            decimals: decimals
        });
    }

    function mul(Amount memory x, Amount memory y) internal pure returns(Amount memory) {
        return Amount({
            amount: x.amount * y.amount / 10**(y.decimals),
            decimals: x.decimals
        });
    }

    function mulDiv(Amount memory x, Amount memory y, Amount memory z) internal pure returns(Amount memory) {
        require(z.amount > 0, "No div by zero");
        return Amount({
            amount: (x.amount * y.amount * 10**(z.decimals)) / (z.amount * 10**(y.decimals)),
            decimals: x.decimals
        });
    }

    function sum(Amount memory x, Amount memory y) internal pure returns(Amount memory) {
        require(x.decimals == y.decimals, "Different Decimal Representation");
        return Amount({
            amount: x.amount + y.amount,
            decimals: x.decimals
        });
    }

    function diff(Amount memory x, Amount memory y) internal pure returns(Amount memory) {
        require(x.decimals == y.decimals, "Different Decimal Representation");
        return Amount({
            amount: x.amount - y.amount,
            decimals: x.decimals
        });
    }


    function getTotalStaken(address xsynth, uint256 dexIndex, address token) internal view returns(Amount memory totStaken) {
        // TODO: Ideally do not assume oracle decimals is 18 but get it from a method
        console.log("[getTotalStaken()] Start");
        totStaken = sum(
            Amount({
                amount: xusdl.totalSupply(),
                decimals: xusdl.decimals()
                }), 
                mul(
                    Amount({
                        amount: IERC20Decimals(xsynth).totalSupply(),
                        decimals: IERC20Decimals(xsynth).decimals()
                    }),
                    Amount({
                        amount: IUSDLemmaAdditional(address(usdl)).getIndexPrice(dexIndex, token),
                        decimals: 18        // NOTE: Assuming the oracle is 18 decimals representation 
                    })
                )
        );
        console.log("[getTotalStaken()] End");
    }

    function print(string memory s, Amount memory x) internal view {
        console.log(s);
        console.log("Amount = ", x.amount);
        console.log("Decimals = ", x.decimals);
    }

    function distributeToXUSDL(Amount memory totalBalance, Amount memory totalStaken, uint256 dexIndex, address _token) internal returns(Amount memory collateralAmountToXUSDL) {
        // NOTE: Same decimal representation
        collateralAmountToXUSDL.decimals = totalBalance.decimals;
        if(xusdl.totalSupply() > 0) {
            console.log("[distributeToXUSDL()] totalBalance.amount = ", totalBalance.amount);
            console.log("[distributeToXUSDL()] totalBalance.decimals = ", totalBalance.decimals);
            Amount memory xUSDLTotalSupply = Amount({
                amount: xusdl.totalSupply(),
                decimals: xusdl.decimals()
            }); 


            collateralAmountToXUSDL = mulDiv(totalBalance, xUSDLTotalSupply, totalStaken);


            console.log("[distributeToXUSDL()] collateralAmountToXUSDL.amount = ", collateralAmountToXUSDL.amount);
            console.log("[distributeToXUSDL()] collateralAmountToXUSDL.decimals = ", collateralAmountToXUSDL.decimals);
            // collateralAmountToXUSDL_nd = ((totalBalance_nd * xusdl.totalSupply())) / (totStaken_xusdlDecimals);
            // uint256 collateralAmount = ((totalBalance / 2) * 1e18) / (10**decimals);

            // IERC20Decimals(_token).approve(address(usdl), 0);
            IERC20Decimals(_token).approve(address(usdl), collateralAmountToXUSDL.amount);
            uint256 amount = convertDecimals(collateralAmountToXUSDL, 18).amount;
            console.log("T111111111 amount = ", amount);
            usdl.depositToWExactCollateral(
                address(xusdl),
                amount,         // NOTE: This API expects 18d representation
                dexIndex,
                0,
                IERC20(_token)
            );
            console.log("T333333333");
        } else {
            console.log("[distributeToXUSDL()] XUSDL No Stake");
        }
    }


    function distributeToXSynth(Amount memory collateralAmountToXSynth, SynthAddresses memory _sa, uint256 dexIndex, address _token, bytes calldata _swapData) internal {
        if(IERC20Decimals(_sa.xSynthAddress).totalSupply() > 0)
        {
            address settlmentToken = usdl.perpSettlementToken();

            // collateralAmount = synthAmount;
            if (_token != settlmentToken) {
                address _tokenOut = settlmentToken;

                // decimals = IERC20Decimals(settlmentToken).decimals();
                IERC20Decimals(_token).approve(router, 0);
                IERC20Decimals(_token).approve(router, collateralAmountToXSynth.amount);

                // NOTE: New amount in Settlement Token Decimals
                Amount memory collateralAmountToXSynth = Amount({
                    amount: _swap(router, _tokenOut, _swapData),
                    decimals: IERC20Decimals(settlmentToken).decimals()
                });
            }

            // IERC20Decimals(IERC20Decimals(settlmentToken)).approve(_sa.synthAddress, 0);
            IERC20Decimals(IERC20Decimals(settlmentToken)).approve(_sa.synthAddress, collateralAmountToXSynth.amount);

            // collateralAmount = (collateralAmount * 1e18) / (10**decimals);

            ILemmaSynth(_sa.synthAddress).depositToWExactCollateral(
                _sa.xSynthAddress,
                convertDecimals(collateralAmountToXSynth, 18).amount,
                0,
                0,
                IERC20(settlmentToken)
            );
        } else {
            console.log("[distributeToXSynth()] xSynth No Stake");
        }
    }

    /// @notice distibuteFees function will distribute fees of any token between xUsdl and xLemmaSynth contract address
    /// @param _token erc20 tokenAddress to tranfer as a gees betwwn xUsdl and xLemmaSynth
    /// @param _swapData swap data to do the actual swap
    function distibuteFees(address _token, bytes calldata _swapData)
        external
        onlyRole(FEES_TRANSFER_ROLE)
    {
        Amount memory totalBalance = Amount({
            amount: IERC20Decimals(_token).balanceOf(address(this)),
            decimals: IERC20Decimals(_token).decimals()
        });

        if (_token == address(usdl)) {
            usdl.transfer(address(xusdl), totalBalance.amount);
            return;
        }
        // uint256 decimals = IERC20Decimals(_token).decimals();
        require(totalBalance.amount > 0, "!totalBalance");
        uint256 dexIndex = _convertCollateralToValidDexIndex(_token, true);


        SynthAddresses memory _sa = synthMapping[_token];
        
        // TODO: Ideally do not assume oracle decimals is 18 but get it from a method
        Amount memory totalStaken = getTotalStaken(_sa.xSynthAddress, dexIndex, _token);
        // uint256 totStaken_xusdlDecimals = xusdl.totalSupply() + (_sa.xSynthAddress.totalSupply() * IUSDLemma(usdl).getIndexPrice(dexIndex, _token) / 1e18); 

        Amount memory collateralAmountToXUSDL = distributeToXUSDL(totalBalance, totalStaken, dexIndex, _token);

        // if(xusdl.totalSupply() > 0) {
        //     collateralAmountToXUSDL = mulDiv(totalBalance, Amount({
        //         amount: xusdl.totalSupply(),
        //         decimals: xusdl.decimals()
        //     }), 
        //     totStaken);
        //     // collateralAmountToXUSDL_nd = ((totalBalance_nd * xusdl.totalSupply())) / (totStaken_xusdlDecimals);
        //     // uint256 collateralAmount = ((totalBalance / 2) * 1e18) / (10**decimals);

        //     // IERC20Decimals(_token).approve(address(usdl), 0);
        //     IERC20Decimals(_token).approve(address(usdl), collateralAmountToXUSDL.amount);
        //     usdl.depositToWExactCollateral(
        //         address(xusdl),
        //         convertDecimals(collateralAmountToXUSDL, 18).amount,         // NOTE: This API expects 18d representation
        //         dexIndex,
        //         0,
        //         IERC20(_token)
        //     );
        // }

        console.log("TotalBalance Decimals = ", totalBalance.decimals);
        console.log("collateralAmountToXUSDL Decimals = ", collateralAmountToXUSDL.decimals);

        console.log("[distibuteFees()] T1");
        distributeToXSynth(diff(totalBalance, collateralAmountToXUSDL), _sa, dexIndex, _token, _swapData);
        console.log("[distibuteFees()] T3");

        // if(IERC20Decimals(_sa.xSynthAddress).totalSupply() > 0)
        // {
        //     collateralAmountToXSynth = diff(totalBalance, collateralAmountToXUSDL);

        //     address settlmentToken = usdl.perpSettlementToken();

        //     // collateralAmount = synthAmount;
        //     if (_token != settlmentToken) {
        //         address _tokenOut = settlmentToken;

        //         // decimals = IERC20Decimals(settlmentToken).decimals();
        //         IERC20Decimals(_token).approve(router, 0);
        //         IERC20Decimals(_token).approve(router, collateralAmountToXSynth.amount);

        //         // NOTE: New amount in Settlement Token Decimals
        //         Amount memory collateralAmountToXSynth = Amount({
        //             amount: _swap(router, _tokenOut, _swapData),
        //             decimals: IERC20Decimals(settlmentToken).decimals()
        //         });
        //     }

        //     // IERC20Decimals(IERC20Decimals(settlmentToken)).approve(_sa.synthAddress, 0);
        //     IERC20Decimals(IERC20Decimals(settlmentToken)).approve(_sa.synthAddress, collateralAmountToXSynth.amount);

        //     // collateralAmount = (collateralAmount * 1e18) / (10**decimals);

        //     ILemmaSynth(_sa.synthAddress).depositToWExactCollateral(
        //         _sa.xSynthAddress,
        //         convertDecimals(collateralAmountToXSynth, 18).amount,
        //         0,
        //         0,
        //         IERC20(settlmentToken)
        //     );
        // }
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
        require(balanceAfter >= balanceBefore, "Swap failed");
        res = uint256(int256(balanceAfter) - int256(balanceBefore));
    }
}
