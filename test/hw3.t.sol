// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../script/hw3.s.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";
import "../src/AaveFlashLoan.sol";

// 看 /Users/max881230/Desktop/blockchain_course/week_12/Blockchain-Resource/section3/CompoundPractice/test/CompoundPractice.t.sol
contract hw3_test is Test, compoundScript {
    uint256 mainnetFork;
    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    uint256 initialUNIBalance = 10000 * 10 ** 18;
    uint256 initialUSDCBalance = 10000 * 10 ** 6;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(MAINNET_RPC_URL);

        vm.selectFork(mainnetFork);
        vm.rollFork(17_465_000);
        assertEq(block.number, 17_465_000);

        vm.startPrank(admin);
        deploycToken(admin);

        unitrollerProxy._supportMarket(CToken(address(cUSDC)));
        unitrollerProxy._supportMarket(CToken(address(cUNI)));

        deal(address(USDC), admin, initialUSDCBalance);
        deal(address(UNI), user1, initialUNIBalance);
        // deal(address(USDC), user2, initialUSDCBalance);

        priceOracle.setUnderlyingPrice(CToken(address(cUSDC)), 1e30);
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 5 * 1e18);

        unitrollerProxy._setCollateralFactor(CToken(address(cUNI)), 5 * 1e17);
        unitrollerProxy._setCloseFactor(5 * 1e17);
        unitrollerProxy._setLiquidationIncentive(1.08 * 1e18);

        vm.stopPrank();
    }

    function testMint() public {
        vm.startPrank(user1);

        // mint
        uint256 mintAmount = 1000 * 10 ** 18;
        UNI.approve(address(cUNI), mintAmount);
        cUNI.mint(mintAmount);
        assertEq(cUNI.balanceOf(user1), mintAmount);

        vm.stopPrank();
    }

    function testMintAndBorrow() public {
        testMint();

        vm.startPrank(user1);

        // enter markets
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUNI);
        unitrollerProxy.enterMarkets(cTokens);
        vm.stopPrank();

        // add some liquidity into USDC for borrowing
        vm.startPrank(admin);
        USDC.approve(address(cUSDC), 10000 * 10 ** 6);
        cUSDC.mint(10000 * 10 ** 6);
        assertEq(cUSDC.balanceOf(admin), 10000 * 10 ** 18);
        vm.stopPrank();

        // borrow USDC
        vm.startPrank(user1);
        uint256 borrowAmount = 2500 * 10 ** 6;
        cUSDC.borrow(borrowAmount);
        assertEq(USDC.balanceOf(user1), borrowAmount);

        vm.stopPrank();
    }

    function testSetOraclePriceAndLiquidatoin() public {
        testMintAndBorrow();

        // adjust UNI price from 5 usd to 4 usd
        vm.startPrank(admin);
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 4 * 1e18);
        vm.stopPrank();

        (uint err, uint liquidity, uint shortfall) = unitrollerProxy
            .getAccountLiquidity(user1);
        require(shortfall > 0, "asset can be liquidated");
        // user2 start liquidation with aave protocol
        vm.startPrank(user2);

        uint256 repayAmount = 1250 * 10 ** 6;
        AaveFlashLoan aaveFlashLoan = new AaveFlashLoan();
        aaveFlashLoan.execute(repayAmount, cUSDC, cUNI, user1, user2);

        // result : earn 63.63 USDC
        assertGt(USDC.balanceOf(user2), 0);
        console2.log(
            "user2's liquidation reward: ",
            USDC.balanceOf(user2) / 1e6,
            "USDC"
        );
        vm.stopPrank();
    }
}
