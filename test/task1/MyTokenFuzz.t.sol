// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/task1/MyToken.sol";

contract MyTokenFuzzTest is Test {
    MyToken public token;
    address public owner = address(1);

    function setUp() public {
        token = new MyToken();
        vm.prank(owner);
        token.mint(owner, 1000000 * 10 ** 18);
    }

    // Fuzz Test 1: Transfer with random amounts
    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, 1000000 * 10 ** 18);

        vm.prank(owner);
        if (amount > 0) {
            token.transfer(address(2), amount);
            assertEq(token.balanceOf(address(2)), amount);
            assertEq(token.balanceOf(owner), 1000000 * 10 ** 18 - amount);
        }
    }

    // Fuzz Test 2: Approve and transferFrom with random amounts
    function testFuzz_ApproveAndTransferFrom(uint256 amount) public {
        amount = bound(amount, 0, 1000000 * 10 ** 18);

        vm.prank(owner);
        token.approve(address(2), amount);

        vm.prank(address(2));
        if (amount > 0) {
            token.transferFrom(owner, address(3), amount);
            assertEq(token.balanceOf(address(3)), amount);
        }
    }

    // Fuzz Test 3: Multiple transfers don't exceed total supply
    function testFuzz_TransfersNeverExceedTotalSupply(
        uint256 amount1,
        uint256 amount2
    ) public {
        amount1 = bound(amount1, 0, 500000 * 10 ** 18);
        amount2 = bound(amount2, 0, 500000 * 10 ** 18);

        vm.prank(owner);
        token.transfer(address(2), amount1);

        vm.prank(address(2));
        if (amount1 >= amount2) {
            token.transfer(address(3), amount2);
        }

        uint256 sum = token.balanceOf(owner) +
            token.balanceOf(address(2)) +
            token.balanceOf(address(3));
        assertEq(sum, 1000000 * 10 ** 18);
    }
}
