// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/task1/MyToken.sol";

contract MyTokenInvariant is Test {
    MyToken public token;
    address public owner = address(1);

    function setUp() public {
        token = new MyToken();
        vm.prank(owner);
        token.mint(owner, 1000000 * 10 ** 18);
    }

    // Invariant 1: Total supply never changes after transfers
    function invariant_TotalSupplyConstantAfterTransfers() public {
        uint256 initialSupply = token.totalSupply();

        // Simulate transfers
        vm.prank(owner);
        token.transfer(address(2), 100 * 10 ** 18);

        vm.prank(address(2));
        token.transfer(address(3), 50 * 10 ** 18);

        assertEq(token.totalSupply(), initialSupply);
    }

    // Invariant 2: No address can have more than total supply
    function invariant_NoAddressCanHaveMoreThanTotalSupply() public {
        vm.prank(owner);
        token.mint(address(2), 500000 * 10 ** 18);

        assertTrue(token.balanceOf(address(2)) <= token.totalSupply());
        assertTrue(token.balanceOf(owner) <= token.totalSupply());
    }

    // Invariant 3: Sum of all balances equals total supply (simplified check)
    function invariant_SumOfBalancesEqualsSupply() public {
        vm.prank(owner);
        token.transfer(address(2), 100 * 10 ** 18);
        token.transfer(address(3), 200 * 10 ** 18);

        uint256 sum = token.balanceOf(owner) +
            token.balanceOf(address(2)) +
            token.balanceOf(address(3));
        assertEq(sum, token.totalSupply());
    }

    // Invariant 4: Burning decreases total supply and balance proportionally
    function invariant_BurnDecreasesBothSupplyAndBalance() public {
        uint256 initialSupply = token.totalSupply();
        uint256 initialBalance = token.balanceOf(owner);

        vm.prank(owner);
        token.burn(100 * 10 ** 18);

        assertEq(token.totalSupply(), initialSupply - 100 * 10 ** 18);
        assertEq(token.balanceOf(owner), initialBalance - 100 * 10 ** 18);
    }
}
