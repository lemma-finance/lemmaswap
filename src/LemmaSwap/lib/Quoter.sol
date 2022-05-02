pragma solidity ^0.7.6;
// pragma abicoder v2;

import {IQuoter} from "./interfaces/IQuoter.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {IERC20} from '@weth10/interfaces/IERC20.sol';
// import {StorageAccessible} from "@util-contracts/contracts/storage/StorageAccessible.sol";
import "forge-std/console.sol";



// MockUSDL Interface 
interface IMockUSDL {
    function USDL2Collateral(address collateral, uint256 amount) external view returns (uint256);
    function Collateral2USDL(address collateral, uint256 amount) external view returns (uint256);
}



// Minimal RealUSDL Interface
interface IRealUSDL {
    // Collateral2USDL
    function depositToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 minUSDLToMint,
        address collateral
    ) external;

    // USDL2Collateral
    function withdrawTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 minCollateralAmountToGetBack,
        address collateral
    ) external;

}

contract Quoter is IQuoter {
    // Converts USDL amount to Collateral amount at oracle price

    address public usdl;

    // 0 --> MockUSDL 
    // 1 --> Sim with Real USDL 
    uint256 mode;

    function simulate(
        address targetContract,
        bytes memory calldataPayload
    ) public returns (bytes memory response) {
        // Suppress compiler warnings about not using parameters, while allowing
        // parameters to keep names for documentation purposes. This does not
        // generate code.
        targetContract;
        calldataPayload;

        assembly {
            let internalCalldata := mload(0x40)
            // Store `simulateAndRevert.selector`.
            mstore(internalCalldata, "\xb4\xfa\xba\x09")
            // Abuse the fact that both this and the internal methods have the
            // same signature, and differ only in symbol name (and therefore,
            // selector) and copy calldata directly. This saves us approximately
            // 250 bytes of code and 300 gas at runtime over the
            // `abi.encodeWithSelector` builtin.
            calldatacopy(
                add(internalCalldata, 0x04),
                0x04,
                sub(calldatasize(), 0x04)
            )

            // `pop` is required here by the compiler, as top level expressions
            // can't have return values in inline assembly. `call` typically
            // returns a 0 or 1 value indicated whether or not it reverted, but
            // since we know it will always revert, we can safely ignore it.
            pop(call(
                gas(),
                address(),
                0,
                internalCalldata,
                calldatasize(),
                // The `simulateAndRevert` call always reverts, and instead
                // encodes whether or not it was successful in the return data.
                // The first 32-byte word of the return data contains the
                // `success` value, so write it to memory address 0x00 (which is
                // reserved Solidity scratch space and OK to use).
                0x00,
                0x20
            ))


            // Allocate and copy the response bytes, making sure to increment
            // the free memory pointer accordingly (in case this method is
            // called as an internal function). The remaining `returndata[0x20:]`
            // contains the ABI encoded response bytes, so we can just write it
            // as is to memory.
            let responseSize := sub(returndatasize(), 0x20)
            response := mload(0x40)
            mstore(0x40, add(response, responseSize))
            returndatacopy(response, 0x20, responseSize)

            if iszero(mload(0x00)) {
                revert(add(response, 0x20), mload(response))
            }
        }
    }

    function setMode(uint256 _mode) external override {
        mode = _mode;
    }

    function setUSDLemma(address _usdl) external {
        usdl = _usdl;
    }

    // This is what gets called by the Sim
    function _Collateral2USDL(address collateral, uint256 amount) public returns (uint256) {
            // TODO: Use Simulate

            // TODO: Replace with input arg
            uint256 perpetualDEXIndex = 0;

            uint256 minUSDLToMint = 0;

            if(IERC20(collateral).allowance(address(this), usdl) < type(uint256).max) {
                IERC20(collateral).approve(usdl, type(uint256).max);
            }

            TransferHelper.safeTransferFrom(collateral, msg.sender, address(this), amount);

            IRealUSDL(usdl).depositToWExactCollateral(address(this), amount, perpetualDEXIndex, minUSDLToMint, collateral);

            return IERC20(usdl).balanceOf(address(this));

    }

    // This is what gets called by the Sim
    function _USDL2Collateral(address collateral, uint256 amount) public returns (uint256) {
            // TODO: Use Simulate

            // TODO: Replace with input arg
            uint256 perpetualDEXIndex = 0;

            uint256 minCollateralAmountToGetBack = 0;

            if(IERC20(usdl).allowance(address(this), usdl) < type(uint256).max) {
                IERC20(usdl).approve(usdl, type(uint256).max);
            }

            TransferHelper.safeTransferFrom(usdl, msg.sender, address(this), amount);

            IRealUSDL(usdl).withdrawTo(address(this), amount, perpetualDEXIndex, minCollateralAmountToGetBack, collateral);

            return IERC20(collateral).balanceOf(address(this));

    }


    function USDL2Collateral(address collateral, uint256 amount) external override returns (uint256) {
        if(mode == 1) {
            bytes memory simFunc = abi.encodeWithSelector(this._USDL2Collateral.selector, collateral, amount);
            bytes memory res = simulate(address(this), simFunc);
            uint256 collateralAmount = abi.decode(res, (uint256));
            return collateralAmount;
        }
        return IMockUSDL(usdl).USDL2Collateral(collateral, amount);
    }

    function Collateral2USDL(address collateral, uint256 amount) external override returns (uint256) { 
        if(mode == 1) {
            bytes memory simFunc = abi.encodeWithSelector(this._Collateral2USDL.selector, collateral, amount);
            bytes memory res = simulate(address(this), simFunc);
            uint256 usdlAmount = abi.decode(res, (uint256));
            return usdlAmount;
        }
        return IMockUSDL(usdl).Collateral2USDL(collateral, amount);
    }
}





