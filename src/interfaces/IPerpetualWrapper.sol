pragma solidity ^0.7.6;

interface IPerpetualWrapper {
    function open(uint256 amount, uint256 collateralAmountRequired) external;

    function openWExactCollateral(uint256 collateralAmount) external returns (uint256 USDLToMint);

    function close(uint256 amount, uint256 collateralAmountToGetBack) external;

    function closeWExactCollateral(uint256 collateralAmount) external returns (uint256 USDLToBurn);

    function getFeesPerc(bool isMinting) external view returns (uint256);

    function getCollateralAmountGivenUnderlyingAssetAmount(uint256 amount, bool isShorting)
        external
        returns (uint256 collateralAmountRequired);

    function reBalance(
        address _reBalancer,
        int256 amount,
        bytes calldata data
    ) external returns (bool);

    function getAmountInCollateralDecimals(uint256 amount, bool roundUp) external view returns (uint256);
}
