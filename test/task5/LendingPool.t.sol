// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/task5/LendingPool.sol";
import "../../src/task5/LendToken.sol";

contract LendingPoolTest is Test {
    LendingPool public pool;
    LendToken public token;

    address public alice = address(1);
    address public bob = address(2);
    address public charlie = address(3);
    address public liquidator = address(4);

    function setUp() public {
        // Deploy token
        token = new LendToken();

        // Deploy pool
        pool = new LendingPool(address(token));

        // Mint tokens to users
        token.mint(alice, 10000 * 10**18);
        token.mint(bob, 10000 * 10**18);
        token.mint(charlie, 10000 * 10**18);
        token.mint(liquidator, 10000 * 10**18);

        // Mint extra tokens to pool for initial liquidity
        token.mint(address(pool), 50000 * 10**18);
    }

    // ==================== TEST 1-5: DEPOSIT & WITHDRAWAL ====================

    function test_Deposit() public {
        uint256 amount = 1000 * 10**18;

        vm.prank(alice);
        token.approve(address(pool), amount);

        vm.prank(alice);
        pool.deposit(amount);

        (uint256 collateral, ) = pool.getPosition(alice);
        assertEq(collateral, amount);
        assertEq(pool.totalCollateral(), amount);
    }

    function test_DepositMultipleUsers() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;

        // Alice deposits
        vm.prank(alice);
        token.approve(address(pool), amount1);
        vm.prank(alice);
        pool.deposit(amount1);

        // Bob deposits
        vm.prank(bob);
        token.approve(address(pool), amount2);
        vm.prank(bob);
        pool.deposit(amount2);

        assertEq(pool.totalCollateral(), amount1 + amount2);
    }

    function test_DepositZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be greater than 0");
        pool.deposit(0);
    }

    function test_WithdrawPartial() public {
        uint256 deposit = 1000 * 10**18;
        uint256 withdraw = 300 * 10**18;

        vm.prank(alice);
        token.approve(address(pool), deposit);
        vm.prank(alice);
        pool.deposit(deposit);

        vm.prank(alice);
        pool.withdraw(withdraw);

        (uint256 collateral, ) = pool.getPosition(alice);
        assertEq(collateral, deposit - withdraw);
    }

    function test_WithdrawFull() public {
        uint256 deposit = 1000 * 10**18;

        vm.prank(alice);
        token.approve(address(pool), deposit);
        vm.prank(alice);
        pool.deposit(deposit);

        vm.prank(alice);
        pool.withdraw(deposit);

        (uint256 collateral, ) = pool.getPosition(alice);
        assertEq(collateral, 0);
    }

    // ==================== TEST 6-10: BORROW & REPAY ====================

    function test_BorrowWithinLTV() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18; // 50% of 1000, within 75% LTV

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        (, uint256 borrowed) = pool.getPosition(alice);
        assertEq(borrowed, borrowAmount);
        assertEq(pool.totalBorrowed(), borrowAmount);
    }

    function test_BorrowExceedsLTV() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 800 * 10**18; // 80% exceeds 75% LTV

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        vm.expectRevert("Exceeds LTV limit");
        pool.borrow(borrowAmount);
    }

    function test_BorrowZeroAmount() public {
        uint256 collateral = 1000 * 10**18;

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        vm.expectRevert("Amount must be greater than 0");
        pool.borrow(0);
    }

    function test_RepayPartial() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18;
        uint256 repayAmount = 200 * 10**18;

        // Deposit
        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        // Borrow
        vm.prank(alice);
        pool.borrow(borrowAmount);

        // Repay
        vm.prank(alice);
        token.approve(address(pool), repayAmount);
        vm.prank(alice);
        pool.repay(repayAmount);

        (, uint256 borrowed) = pool.getPosition(alice);
        assertEq(borrowed, borrowAmount - repayAmount);
    }

    function test_RepayFull() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18;

        // Deposit
        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        // Borrow
        vm.prank(alice);
        pool.borrow(borrowAmount);

        // Repay full
        vm.prank(alice);
        token.approve(address(pool), borrowAmount);
        vm.prank(alice);
        pool.repay(borrowAmount);

        (, uint256 borrowed) = pool.getPosition(alice);
        assertEq(borrowed, 0);
    }

    // ==================== TEST 11-15: INTEREST & HEALTH FACTOR ====================

    function test_InterestAccrual() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18;

        // Deposit and borrow
        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        (, uint256 borrowedBefore) = pool.getPosition(alice);

        // Move time forward (1 year)
        vm.warp(block.timestamp + 365 days);

        // Accrue interest
        pool.accrueInterest(alice);

        (, uint256 borrowedAfter) = pool.getPosition(alice);

        // Should have accrued 5% interest
        uint256 expectedInterest = (borrowAmount * 5) / 100;
        assertGt(borrowedAfter, borrowedBefore);
        assertEq(borrowedAfter, borrowAmount + expectedInterest);
    }

    function test_HealthFactorSafe() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18; // 50% LTV, safe

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        uint256 hf = pool.getHealthFactor(alice);
        assertGt(hf, 100); // HF > 1
        assertFalse(pool.isLiquidatable(alice));
    }

    function test_HealthFactorDanger() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 750 * 10**18; // 75% LTV, at limit

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        uint256 hf = pool.getHealthFactor(alice);
        assertEq(hf, 100); // HF = 1, at threshold
    }

    function test_WithdrawWhileBorrowed() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18;
        uint256 withdrawAmount = 300 * 10**18;

        // Deposit and borrow
        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        // Try to withdraw more than allowed
        vm.prank(alice);
        vm.expectRevert("Withdrawal would make position unhealthy");
        pool.withdraw(withdrawAmount);
    }

    function test_WithdrawAllowedAmount() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18;
        uint256 withdrawAmount = 100 * 10**18; // Safe withdrawal

        // Deposit and borrow
        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        // Withdraw safe amount
        vm.prank(alice);
        pool.withdraw(withdrawAmount);

        (uint256 remainingCollateral, ) = pool.getPosition(alice);
        assertEq(remainingCollateral, collateral - withdrawAmount);
    }

    // ==================== TEST 16-20: LIQUIDATION ====================

    function test_LiquidateUndercollateralized() public {
        // Alice deposits and borrows at maximum LTV
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 750 * 10**18; // 75% LTV

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        // Move time forward so interest accrues (pushes HF below 1)
        vm.warp(block.timestamp + 30 days);
        pool.accrueInterest(alice);

        // Verify position is liquidatable
        assertTrue(pool.isLiquidatable(alice));

        // Liquidator repays 200 tokens
        uint256 repayAmount = 200 * 10**18;

        vm.prank(liquidator);
        token.approve(address(pool), repayAmount);
        vm.prank(liquidator);
        pool.liquidate(alice, repayAmount);

        // Verify liquidation occurred
        (, uint256 borrowed) = pool.getPosition(alice);
        assertLt(borrowed, borrowAmount);
    }

    function test_LiquidationBonus() public {
        // Setup
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 750 * 10**18;

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        // Accrue interest to become liquidatable
        vm.warp(block.timestamp + 30 days);
        pool.accrueInterest(alice);

        uint256 liquidatorBalanceBefore = token.balanceOf(liquidator);

        // Liquidate
        uint256 repayAmount = 100 * 10**18;
        vm.prank(liquidator);
        token.approve(address(pool), repayAmount);
        vm.prank(liquidator);
        pool.liquidate(alice, repayAmount);

        // Liquidator should receive repayAmount + 10% bonus
        uint256 expectedSeized = repayAmount + (repayAmount * 10) / 100;
        uint256 liquidatorBalanceAfter = token.balanceOf(liquidator);

        assertEq(liquidatorBalanceAfter, liquidatorBalanceBefore - repayAmount + expectedSeized);
    }

    function test_CannotLiquidateSafePosition() public {
        uint256 collateral = 1000 * 10**18;
        uint256 borrowAmount = 500 * 10**18; // Safe 50% LTV

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        vm.prank(alice);
        pool.borrow(borrowAmount);

        // Try to liquidate (should fail - position is safe)
        vm.prank(liquidator);
        vm.expectRevert("Position is not liquidatable");
        pool.liquidate(alice, 100 * 10**18);
    }

    function test_MaxBorrowCalculation() public {
        uint256 collateral = 1000 * 10**18;

        vm.prank(alice);
        token.approve(address(pool), collateral);
        vm.prank(alice);
        pool.deposit(collateral);

        uint256 maxBorrow = pool.getMaxBorrow(alice);
        assertEq(maxBorrow, (collateral * 75) / 100); // 75% of collateral
    }

    function test_AvailableLiquidity() public {
        uint256 deposit = 1000 * 10**18;

        vm.prank(alice);
        token.approve(address(pool), deposit);
        vm.prank(alice);
        pool.deposit(deposit);

        uint256 availableLiquidity = pool.getAvailableLiquidity();
        assertGt(availableLiquidity, 0);
    }
}
