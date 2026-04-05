# Fuzz Testing vs Unit Testing

## Unit Testing
Unit tests verify specific, predetermined scenarios. You manually define inputs and expected outputs.

**When to use:**
- Testing critical business logic (e.g., correct ERC-20 balance updates)
- Edge cases you know about (zero amounts, zero addresses)
- Deterministic scenarios (specific transfer sequences)

**Example from our tests:**
```solidity
function test_Transfer() public {
    vm.prank(owner);
    token.transfer(alice, 100 * 10**18);
    assertEq(token.balanceOf(alice), 100 * 10**18);
}
```

## Fuzz Testing
Fuzz tests use Foundry's fuzzer to generate random inputs automatically, testing your contract with thousands of combinations.

**When to use:**
- Finding unexpected edge cases
- Testing with large ranges of values (0 to max uint256)
- Validating invariants across many scenarios
- Discovering bugs in unexpected input combinations

**Example from our tests:**
```solidity
function testFuzz_Transfer(uint256 amount) public {
    amount = bound(amount, 0, 1000000 * 10**18);
    vm.prank(owner);
    token.transfer(address(2), amount);
    // Foundry tests this with 256+ random amounts automatically
}
```

## Key Differences

| Aspect | Unit Testing | Fuzz Testing |
|--------|-------------|--------------|
| Input generation | Manual | Automatic/Random |
| Number of runs | Fixed (you write them) | 256+ runs per test |
| Edge case discovery | Limited to what you think of | Comprehensive |
| Execution time | Fast | Slower (more runs) |
| Coverage | You control | Foundry controls |

## Why Both Matter

- **Unit tests**: Ensure documented behavior works correctly
- **Fuzz tests**: Discover undocumented bugs in unexpected scenarios

For our ERC-20 token:
- Unit tests verify standard ERC-20 behavior (approve, transfer, transferFrom)
- Fuzz tests verify no value is lost in transfers across random amounts
- Invariant tests ensure the contract's core properties always hold
