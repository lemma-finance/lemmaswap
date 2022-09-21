// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDLemma is IERC20 {
    function depositTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 maxCollateralRequired,
        IERC20 collateral
    ) external;

    function withdrawTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 minCollateralToGetBack,
        IERC20 collateral
    ) external;

    function depositToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 minUSDLToMint,
        IERC20 collateral
    ) external;

    function withdrawToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 maxUSDLToBurn,
        IERC20 collateral
    ) external;

    function perpetualDEXWrappers(uint256 perpetualDEXIndex, address collateral)
        external
        view
        returns (address);

    function addPerpetualDEXWrapper(
        uint256 perpetualDEXIndex,
        address collateralAddress,
        address perpetualDEXWrapperAddress
    ) external;

    function perpSettlementToken() external view returns (address);

    function getFeesPerc(
        uint256 dexIndex,
        address collateral,
        bool isMinting
    ) external view returns (uint256);

    function setWhiteListAddress(address _account, bool _isWhiteList) external;

    function setConsultingContract(address _consultingContract) external;

    function nonces(address owner) external view returns (uint256);

    function name() external view returns (string memory);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function closePosition(
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        IERC20 collateral
    ) external returns (uint256, uint256);

    function burnAndTransfer(
        uint256 USDLToBurn,
        uint256 collateralAmountToGetBack,
        address to,
        IERC20 collateral
    ) external;

    function grantRole(bytes32 role, address account) external;

    function getFees(
        uint256 dexIndex,
        address collateral,
        bool isMinting
    ) external view returns (uint256);

    function getTotalPosition(uint256 dexIndex, address collateral)
        external
        view
        returns (int256);

    function lemmaTreasury() external view returns (address);

    event PerpetualDexWrapperAdded(
        uint256 indexed dexIndex,
        address indexed collateral,
        address dexWrapper
    );
}
