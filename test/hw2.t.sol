// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../script/hw1.s.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";
import {ComptrollerV1Storage} from "compound-protocol/contracts/ComptrollerStorage.sol";

contract hw2_test is Test, compoundScript {
    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    uint256 initialBalance = 100 * 10 ** 18;

    function setUp() public {
        vm.startPrank(admin);
        deploycToken(admin);

        unitrollerProxy._supportMarket(CToken(address(cTokenA)));
        unitrollerProxy._supportMarket(CToken(address(cTokenB)));

        deal(address(tokenA), admin, initialBalance);
        deal(address(tokenA), user1, initialBalance);
        deal(address(tokenB), user1, initialBalance);
        deal(address(tokenA), user2, initialBalance);

        priceOracle.setUnderlyingPrice(CToken(address(cTokenA)), 1e18);
        priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 100 * 1e18);

        unitrollerProxy._setCollateralFactor(
            CToken(address(cTokenB)),
            5 * 1e17
        );
        unitrollerProxy._setCloseFactor(5 * 1e17);
        unitrollerProxy._setLiquidationIncentive(1.08 * 1e18);
        vm.stopPrank();
    }

    function testMintAndRedeem() public {
        vm.startPrank(user1);

        // mint
        uint256 mintAmount = 100 * 10 ** 18;
        tokenA.approve(address(cTokenA), mintAmount);
        cTokenA.mint(mintAmount);
        assertEq(cTokenA.balanceOf(user1), mintAmount);
        assertEq(tokenA.balanceOf(user1), 0);

        // redeem
        cTokenA.redeem(mintAmount);
        assertEq(cTokenA.balanceOf(user1), 0);
        assertEq(tokenA.balanceOf(user1), initialBalance);

        vm.stopPrank();
    }

    function testBorrowAndRepay() public {
        vm.startPrank(user1);

        // mint
        uint256 mintAmount = 1 * 10 ** 18;
        tokenB.approve(address(cTokenB), mintAmount);
        cTokenB.mint(mintAmount);
        assertEq(cTokenB.balanceOf(user1), mintAmount);

        // enter market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        unitrollerProxy.enterMarkets(cTokens);

        vm.stopPrank();

        // add some liquidity into cTokenA for borrowing
        vm.startPrank(admin);
        tokenA.approve(address(cTokenA), 100 * 10 ** 18);
        cTokenA.mint(100 * 10 ** 18);
        assertEq(cTokenA.balanceOf(admin), 100 * 10 ** 18);
        vm.stopPrank();

        // borrow
        vm.startPrank(user1);
        uint256 borrowAmount = 50 * 10 ** tokenA.decimals();
        cTokenA.borrow(borrowAmount);
        assertEq(tokenA.balanceOf(user1), initialBalance + borrowAmount);
        vm.stopPrank();
    }

    function testAdjustCollateralFactorAndLiquidation() public {
        testBorrowAndRepay();

        (uint err, uint liquidity, uint shortfall) = unitrollerProxy
            .getAccountLiquidity(user1);

        // adjust collateralFactor from 50% to 30%
        vm.startPrank(admin);
        unitrollerProxy._setCollateralFactor(
            CToken(address(cTokenB)),
            3 * 1e17
        );
        vm.stopPrank();

        // user2 starts to liquidate user1's asset
        vm.startPrank(user2);
        (err, liquidity, shortfall) = unitrollerProxy.getAccountLiquidity(
            user1
        );

        uint closeFactorMantissa = unitrollerProxy.closeFactorMantissa();
        uint borrowBalance = cTokenA.borrowBalanceCurrent(user1);
        uint repayAmount = (borrowBalance * closeFactorMantissa) / 1e18;

        console2.log(closeFactorMantissa / 1e16);
        console2.log(borrowBalance / 1e18);
        console2.log(repayAmount / 10 ** tokenA.decimals());

        tokenA.approve(address(cTokenA), repayAmount);
        cTokenA.liquidateBorrow(user1, repayAmount, cTokenB);
        assertGt(cTokenB.balanceOf(user2), 0);

        console2.log("cTokenB of user2: ", cTokenB.balanceOf(user2));
        vm.stopPrank();
    }

    function testSetOraclePriceAndLiquidatoin() public {
        testBorrowAndRepay();

        (uint err, uint liquidity, uint shortfall) = unitrollerProxy
            .getAccountLiquidity(user1);

        // adjust 1 tokenB from 100USD to 90USD
        vm.startPrank(admin);
        priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 90 * 1e18);
        vm.stopPrank();

        // user2 starts to liquidate user1's asset
        vm.startPrank(user2);

        (err, liquidity, shortfall) = unitrollerProxy.getAccountLiquidity(
            user1
        );

        uint closeFactorMantissa = unitrollerProxy.closeFactorMantissa();
        uint borrowBalance = cTokenA.borrowBalanceCurrent(user1);
        uint repayAmount = (borrowBalance * closeFactorMantissa) / 1e18;

        console2.log(closeFactorMantissa / 1e16);
        console2.log(borrowBalance / 1e18);
        console2.log(repayAmount / 10 ** tokenA.decimals());

        tokenA.approve(address(cTokenA), repayAmount);
        cTokenA.liquidateBorrow(user1, repayAmount, cTokenB);
        assertGt(cTokenB.balanceOf(user2), 0);

        console2.log("cTokenB of user2: ", cTokenB.balanceOf(user2));
        vm.stopPrank();
    }
}
