// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanSimpleReceiver, IPoolAddressesProvider, IPool} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract AaveFlashLoan is IFlashLoanSimpleReceiver {
    ISwapRouter swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant POOL_ADDRESSES_PROVIDER =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

    // aave pool will call this function
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        (
            CErc20Delegator cUSDC,
            CErc20Delegator cUNI,
            address user1,
            address user2
        ) = abi.decode(
                params,
                (CErc20Delegator, CErc20Delegator, address, address)
            );

        // start liquidation
        IERC20(USDC).approve(address(cUSDC), amount);
        cUSDC.liquidateBorrow(user1, amount, cUNI);
        cUNI.redeem(cUNI.balanceOf(address(this)));

        // swap UNI to USDC
        IERC20(UNI).approve(
            address(swapRouter),
            IERC20(UNI).balanceOf(address(this))
        );
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: UNI,
                tokenOut: asset,
                fee: 3000, // 0.3%
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: IERC20(UNI).balanceOf(address(this)),
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        swapRouter.exactInputSingle(swapParams);

        // approve amount + premium to aave -> 10_000_000 + (0.05%) 5_000
        IERC20(USDC).approve(address(POOL()), amount + premium);

        return true;
    }

    function execute(
        uint256 repayAmount,
        CErc20Delegator cUSDC,
        CErc20Delegator cUNI,
        address user1,
        address user2
    ) external {
        // TODO
        // call flashLoanSimple
        POOL().flashLoanSimple(
            address(this),
            USDC,
            repayAmount,
            abi.encode(cUSDC, cUNI, user1, user2),
            0
        );

        IERC20(USDC).transfer(user2, IERC20(USDC).balanceOf(address(this)));
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }
}
