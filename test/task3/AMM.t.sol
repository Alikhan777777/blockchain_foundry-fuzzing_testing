// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/task3/AMM.sol";
import "../../src/task3/TokenA.sol";
import "../../src/task3/TokenB.sol";
import "../../src/task3/LPToken.sol";

contract AMMTest is Test {
    AMM public amm;
    TokenA public tokenA;
    TokenB public tokenB;
    LPToken public lpToken;

    address public alice = address(1);
    address public bob = address(2);
    address public charlie = address(3);

    function setUp() public {
        // Deploy tokens
        tokenA = new TokenA();
        tokenB = new TokenB();
        lpToken = new LPToken();

        // Deploy AMM
        amm = new AMM(address(tokenA), address(tokenB), address(lpToken));

        // Mint initial tokens to users
        tokenA.mint(alice, 10000 * 10**18);
        tokenB.mint(alice, 10000 * 10**18);
        
        tokenA.mint(bob, 10000 * 10**18);
        tokenB.mint(bob, 10000 * 10**18);
        
        tokenA.mint(charlie, 10000 * 10**18);
        tokenB.mint(charlie, 10000 * 10**18);
    }

    // ==================== TEST 1-5: ADD LIQUIDITY ====================

    function test_AddLiquidityFirstProvider() public {
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        // Alice approves AMM to spend tokens
        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);

        // Add liquidity
        vm.prank(alice);
        uint256 lpMinted = amm.addLiquidity(amountA, amountB, 0);

        // Verify LP tokens minted (should be sqrt(amountA * amountB))
        assertEq(lpToken.balanceOf(alice), lpMinted);
        assertGt(lpMinted, 0);

        // Verify reserves updated
        assertEq(amm.reserveA(), amountA);
        assertEq(amm.reserveB(), amountB);
    }

    function test_AddLiquiditySecondProvider() public {
        // First provider adds liquidity
        uint256 amountA1 = 1000 * 10**18;
        uint256 amountB1 = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA1);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB1);

        vm.prank(alice);
        uint256 lpMinted1 = amm.addLiquidity(amountA1, amountB1, 0);

        // Second provider adds liquidity
        uint256 amountA2 = 500 * 10**18;
        uint256 amountB2 = 500 * 10**18;

        vm.prank(bob);
        tokenA.approve(address(amm), amountA2);
        vm.prank(bob);
        tokenB.approve(address(amm), amountB2);

        vm.prank(bob);
        uint256 lpMinted2 = amm.addLiquidity(amountA2, amountB2, 0);

        // Verify both received LP tokens
        assertGt(lpMinted1, 0);
        assertGt(lpMinted2, 0);
        assertEq(amm.reserveA(), amountA1 + amountA2);
        assertEq(amm.reserveB(), amountB1 + amountB2);
    }

    function test_AddLiquiditySlippageProtection() public {
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);

        // Try to add liquidity with slippage protection that's too high
        vm.prank(alice);
        vm.expectRevert("Slippage protection: insufficient LP output");
        amm.addLiquidity(amountA, amountB, 2000 * 10**18); // Expecting too much LP
    }

    function test_AddLiquidityZeroAmounts() public {
        vm.prank(alice);
        vm.expectRevert("Amounts must be greater than 0");
        amm.addLiquidity(0, 1000 * 10**18, 0);

        vm.prank(alice);
        vm.expectRevert("Amounts must be greater than 0");
        amm.addLiquidity(1000 * 10**18, 0, 0);
    }

    function test_AddLiquidityProportional() public {
        // First provider: 1000 A : 1000 B (ratio 1:1)
        uint256 amountA1 = 1000 * 10**18;
        uint256 amountB1 = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA1);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB1);
        vm.prank(alice);
        amm.addLiquidity(amountA1, amountB1, 0);

        // Second provider: 2000 A : 2000 B (same ratio 1:1)
        uint256 amountA2 = 2000 * 10**18;
        uint256 amountB2 = 2000 * 10**18;

        vm.prank(bob);
        tokenA.approve(address(amm), amountA2);
        vm.prank(bob);
        tokenB.approve(address(amm), amountB2);
        vm.prank(bob);
        uint256 lpMinted2 = amm.addLiquidity(amountA2, amountB2, 0);

        // Bob should receive LP tokens based on proportion
        assertGt(lpMinted2, 0);
        assertEq(amm.reserveA(), amountA1 + amountA2);
        assertEq(amm.reserveB(), amountB1 + amountB2);
    }

    // ==================== TEST 6-10: REMOVE LIQUIDITY ====================

    function test_RemoveLiquidityPartial() public {
        // Add liquidity first
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        uint256 lpMinted = amm.addLiquidity(amountA, amountB, 0);

        // Remove 50% of liquidity
        uint256 lpToRemove = lpMinted / 2;

        vm.prank(alice);
        (uint256 withdrawnA, uint256 withdrawnB) = amm.removeLiquidity(lpToRemove, 0, 0);

        // Verify amounts withdrawn
        assertGt(withdrawnA, 0);
        assertGt(withdrawnB, 0);
        assertLt(withdrawnA, amountA);
        assertLt(withdrawnB, amountB);

        // Verify remaining LP
        assertEq(lpToken.balanceOf(alice), lpMinted - lpToRemove);
    }

    function test_RemoveLiquidityFull() public {
        // Add liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        uint256 lpMinted = amm.addLiquidity(amountA, amountB, 0);

        // Remove all liquidity
        vm.prank(alice);
        (uint256 withdrawnA, uint256 withdrawnB) = amm.removeLiquidity(lpMinted, 0, 0);

        // Verify all LP burned
        assertEq(lpToken.balanceOf(alice), 0);
        
        // Verify reserves reduced (or zero)
        assertEq(amm.reserveA(), 0);
        assertEq(amm.reserveB(), 0);
    }

    function test_RemoveLiquiditySlippageProtection() public {
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        uint256 lpMinted = amm.addLiquidity(amountA, amountB, 0);

        // Try to remove with slippage protection too high
        vm.prank(alice);
        vm.expectRevert("Slippage protection: insufficient A output");
        amm.removeLiquidity(lpMinted, amountA + 1, 0); // Expect more than available
    }

    function test_RemoveLiquidityInsufficientLPBalance() public {
        vm.prank(alice);
        vm.expectRevert("Insufficient LP balance");
        amm.removeLiquidity(1000 * 10**18, 0, 0); // Alice has no LP
    }

    function test_RemoveLiquidityZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("LP amount must be greater than 0");
        amm.removeLiquidity(0, 0, 0);
    }

    // ==================== TEST 11-15: SWAPS ====================

    function test_SwapAForB() public {
        // Setup: Add initial liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        amm.addLiquidity(amountA, amountB, 0);

        // Bob swaps 100 A for B
        uint256 swapAmount = 100 * 10**18;

        vm.prank(bob);
        tokenA.approve(address(amm), swapAmount);
        
        uint256 expectedOut = amm.getAmountOut(swapAmount, amountA, amountB);
        
        vm.prank(bob);
        uint256 actualOut = amm.swapAForB(swapAmount, 0);

        // Verify swap executed
        assertEq(actualOut, expectedOut);
        assertGt(actualOut, 0);
        assertEq(tokenB.balanceOf(bob), 10000 * 10**18 + actualOut);
    }

    function test_SwapBForA() public {
        // Setup: Add initial liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        amm.addLiquidity(amountA, amountB, 0);

        // Bob swaps 100 B for A
        uint256 swapAmount = 100 * 10**18;

        vm.prank(bob);
        tokenB.approve(address(amm), swapAmount);
        
        uint256 expectedOut = amm.getAmountOut(swapAmount, amountB, amountA);
        
        vm.prank(bob);
        uint256 actualOut = amm.swapBForA(swapAmount, 0);

        // Verify swap executed
        assertEq(actualOut, expectedOut);
        assertGt(actualOut, 0);
        assertEq(tokenA.balanceOf(bob), 10000 * 10**18 + actualOut);
    }

    function test_SwapSlippageProtection() public {
        // Setup liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        amm.addLiquidity(amountA, amountB, 0);

        // Try swap with slippage protection
        uint256 swapAmount = 100 * 10**18;
        vm.prank(bob);
        tokenA.approve(address(amm), swapAmount);

        vm.prank(bob);
        vm.expectRevert("Slippage protection: insufficient output");
        amm.swapAForB(swapAmount, 10000 * 10**18); // Expect too much
    }

    function test_SwapBothDirections() public {
        // Setup liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        amm.addLiquidity(amountA, amountB, 0);

        // First swap: A -> B
        uint256 swapA = 100 * 10**18;
        vm.prank(bob);
        tokenA.approve(address(amm), swapA);
        vm.prank(bob);
        uint256 receivedB = amm.swapAForB(swapA, 0);

        // Second swap: B -> A (reverse)
        vm.prank(bob);
        tokenB.approve(address(amm), receivedB);
        vm.prank(bob);
        uint256 receivedA = amm.swapBForA(receivedB, 0);

        // Verify round trip (should lose some due to fees)
        assertLt(receivedA, swapA); // Lost to fees
        assertGt(receivedA, 0);
    }

    // ==================== TEST 16-20: INVARIANT & K ====================

    function test_InvariantKAfterSwap() public {
        // Add liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        amm.addLiquidity(amountA, amountB, 0);

        uint256 kBefore = amm.getK();

        // Perform swap
        uint256 swapAmount = 100 * 10**18;
        vm.prank(bob);
        tokenA.approve(address(amm), swapAmount);
        vm.prank(bob);
        amm.swapAForB(swapAmount, 0);

        uint256 kAfter = amm.getK();

        // k should increase or stay same (fee generates k increase)
        assertGe(kAfter, kBefore);
    }

    function test_NoSingleSidedLiquidity() public {
        // Try to add only token A
        uint256 amountA = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);

        vm.prank(alice);
        vm.expectRevert("Amounts must be greater than 0");
        amm.addLiquidity(amountA, 0, 0);
    }

    function test_LargeSwapWithHighPriceImpact() public {
        // Add liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 1000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        amm.addLiquidity(amountA, amountB, 0);

        // Swap 50% of liquidity (large trade)
        uint256 swapAmount = 500 * 10**18;

        vm.prank(bob);
        tokenA.approve(address(amm), swapAmount);
        
        uint256 expectedOut = amm.getAmountOut(swapAmount, amountA, amountB);

        vm.prank(bob);
        uint256 actualOut = amm.swapAForB(swapAmount, 0);

        // Should get less than linear (due to price impact)
        uint256 linearOut = (swapAmount * amountB) / amountA;
        assertLt(actualOut, linearOut);
        assertEq(actualOut, expectedOut);
    }

    function test_SequentialSwapsReduceOutput() public {
        // Add liquidity
        uint256 amountA = 10000 * 10**18;
        uint256 amountB = 10000 * 10**18;

        vm.prank(alice);
        tokenA.approve(address(amm), amountA);
        vm.prank(alice);
        tokenB.approve(address(amm), amountB);
        vm.prank(alice);
        amm.addLiquidity(amountA, amountB, 0);

        // First swap
        uint256 swapAmount = 100 * 10**18;
        vm.prank(bob);
        tokenA.approve(address(amm), swapAmount);
        vm.prank(bob);
        uint256 out1 = amm.swapAForB(swapAmount, 0);

        // Second identical swap
        vm.prank(charlie);
        tokenA.approve(address(amm), swapAmount);
        vm.prank(charlie);
        uint256 out2 = amm.swapAForB(swapAmount, 0);

        // Second swap should have less output (higher price impact)
        assertLt(out2, out1);
    }
}
