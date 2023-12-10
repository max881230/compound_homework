// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../script/hw1.s.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";

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

    function testAdjustCollateralFactorAndLiquidation() public {}

    function testSetOraclePriceAndLiquidatoin() public {}
}
