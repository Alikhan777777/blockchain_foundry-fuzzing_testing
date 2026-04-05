// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/task1/SimpleToken.sol";

contract SimpleTokenTest is Test {
    SimpleToken public token;

    function setUp() public {
        token = new SimpleToken();
    }

    function test_SupplyIs1000() public view {
        assertEq(token.getSupply(), 1000);
    }
}
