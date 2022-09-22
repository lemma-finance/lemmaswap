// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IXUSDL is IERC20 {
    event Deposit(
        address indexed sender,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    function asset() external view returns (address assetTokenAddress);

    function totalAssets() external view returns (uint256 assets);

    function assetsPerShare()
        external
        view
        returns (uint256 assetsPerUnitShare);

    function assetsOf(address depositor) external view returns (uint256 assets);

    function maxDeposit() external view returns (uint256 maxAssets);

    function previewDeposit(uint256 assets)
        external
        view
        returns (uint256 shares);

    function deposit(uint256 assets, address receiver)
        external
        returns (uint256 shares);

    function maxMint() external view returns (uint256 maxShares);

    function previewMint(uint256 shares) external view returns (uint256 assets);

    function mint(uint256 shares, address receiver)
        external
        returns (uint256 assets);

    function maxWithdraw() external view returns (uint256 maxAssets);

    function previewWithdraw(uint256 assets)
        external
        view
        returns (uint256 shares);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function maxRedeem() external view returns (uint256 maxShares);

    function previewRedeem(uint256 shares)
        external
        view
        returns (uint256 assets);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    // Lemma Specific
    function userUnlockBlock(address usr) external view returns (uint256);

    function minimumLock() external view returns (uint256);

    function setMinimumLock(uint256 _minimumLock) external;

    function usdl() external view returns (IERC20);

    function setPeriphery(address _periphery) external;

    function decimals() external view returns (uint256);

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
}
