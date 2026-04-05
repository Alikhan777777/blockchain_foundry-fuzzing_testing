// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/task1/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    address public owner = address(1);
    address public alice = address(2);
    address public bob = address(3);

    function setUp() public {
        token = new MyToken();
        vm.prank(owner);
        token.mint(owner, 1000 * 10 ** 18);
    }

    // ==================== UNIT TESTS ====================

    // Test 1: Mint tokens
    function test_Mint() public {
        vm.prank(owner);
        token.mint(alice, 100 * 10 ** 18);
        assertEq(token.balanceOf(alice), 100 * 10 ** 18);
        assertEq(token.totalSupply(), 1100 * 10 ** 18);
    }

    // Test 2: Mint to zero address should fail
    function test_MintToZeroAddressFails() public {
        vm.prank(owner);
        vm.expectRevert("Cannot mint to zero address");
        token.mint(address(0), 100 * 10 ** 18);
    }

    // Test 3: Mint zero amount should fail
    function test_MintZeroAmountFails() public {
        vm.prank(owner);
        vm.expectRevert("Amount must be greater than 0");
        token.mint(alice, 0);
    }

    // Test 4: Basic transfer
    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(alice, 100 * 10 ** 18);
        assertEq(token.balanceOf(alice), 100 * 10 ** 18);
        assertEq(token.balanceOf(owner), 900 * 10 ** 18);
    }

    // Test 5: Transfer to zero address fails
    function test_TransferToZeroAddressFails() public {
        vm.prank(owner);
        vm.expectRevert("Cannot transfer to zero address");
        token.transfer(address(0), 100 * 10 ** 18);
    }

    // Test 6: Transfer insufficient balance fails
    function test_TransferInsufficientBalanceFails() public {
        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        token.transfer(bob, 100 * 10 ** 18);
    }

    // Test 7: Approve
    function test_Approve() public {
        vm.prank(owner);
        token.approve(alice, 500 * 10 ** 18);
        assertEq(token.allowance(owner, alice), 500 * 10 ** 18);
    }

    // Test 8: Approve zero address fails
    function test_ApproveZeroAddressFails() public {
        vm.prank(owner);
        vm.expectRevert("Cannot approve zero address");
        token.approve(address(0), 100 * 10 ** 18);
    }

    // Test 9: TransferFrom
    function test_TransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 500 * 10 ** 18);

        vm.prank(alice);
        token.transferFrom(owner, bob, 200 * 10 ** 18);

        assertEq(token.balanceOf(bob), 200 * 10 ** 18);
        assertEq(token.balanceOf(owner), 800 * 10 ** 18);
        assertEq(token.allowance(owner, alice), 300 * 10 ** 18);
    }

    // Test 10: TransferFrom insufficient allowance fails
    function test_TransferFromInsufficientAllowanceFails() public {
        vm.prank(owner);
        token.approve(alice, 50 * 10 ** 18);

        vm.prank(alice);
        vm.expectRevert("Insufficient allowance");
        token.transferFrom(owner, bob, 100 * 10 ** 18);
    }

    // Test 11: Burn tokens
    function test_Burn() public {
        vm.prank(owner);
        token.burn(100 * 10 ** 18);
        assertEq(token.balanceOf(owner), 900 * 10 ** 18);
        assertEq(token.totalSupply(), 900 * 10 ** 18);
    }

    // Test 12: Burn insufficient balance fails
    function test_BurnInsufficientBalanceFails() public {
        vm.prank(alice);
        vm.expectRevert("Insufficient balance to burn");
        token.burn(100 * 10 ** 18);
    }

    // Test 13: Edge case - transfer exact balance
    function test_TransferExactBalance() public {
        vm.prank(owner);
        token.transfer(alice, 1000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(alice), 1000 * 10 ** 18);
    }

    // Test 14: Edge case - multiple transfers
    function test_MultipleTransfers() public {
    vm.prank(owner);
    token.transfer(alice, 300 * 10**18);
    vm.prank(owner);
    token.transfer(bob, 400 * 10**18);
    
    assertEq(token.balanceOf(owner), 300 * 10**18);
    assertEq(token.balanceOf(alice), 300 * 10**18);
    assertEq(token.balanceOf(bob), 400 * 10**18);
}

    // Test 15: Edge case - approve then transfer multiple times
    function test_ApproveThenMultipleTransfers() public {
    vm.prank(owner);
    token.approve(alice, 1000 * 10**18);

    vm.prank(alice);
    token.transferFrom(owner, bob, 200 * 10**18);
    
    vm.prank(alice);
    token.transferFrom(owner, bob, 300 * 10**18);

    assertEq(token.balanceOf(bob), 500 * 10**18);
    assertEq(token.allowance(owner, alice), 500 * 10**18);
    }
}
