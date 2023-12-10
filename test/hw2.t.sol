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
        priceOracle.setUnderlyingPrice(CToken(address(cTokenA)), 1e18);
        vm.stopPrank();

        deal(address(tokenA), user1, initialBalance);
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

    function testBorrowAndRepay() public {}

    function testAdjustCollateralFactorAndLiquidation() public {}

    function testSetOraclePriceAndLiquidatoin() public {}
}
