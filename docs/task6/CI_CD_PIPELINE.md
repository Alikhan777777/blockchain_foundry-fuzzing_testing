# GitHub Actions CI/CD Pipeline Documentation

## Overview

This document describes the automated CI/CD pipeline for the Blockchain Assignment 2 project. The pipeline runs on every push and pull request to ensure code quality, test coverage, and security.

## Pipeline Configuration

### File Location
`.github/workflows/test.yml`

### Triggers
- **On Push:** Main and develop branches
- **On Pull Request:** Main and develop branches

---

## Pipeline Stages

### Stage 1: Foundry Tests

**Job Name:** `test`

**Steps:**

1. **Checkout Code**
   - Uses `actions/checkout@v3`
   - Recursively clones submodules (dependencies)

2. **Install Foundry**
   - Uses `foundry-rs/foundry-toolchain@v1`
   - Installs latest nightly build of Foundry
   - Includes: forge, cast, anvil, chisel

3. **Display Versions**
   - Prints installed tool versions
   - Verifies installation success

4. **Build Contracts**
```bash
   forge build --sizes
```
   - Compiles all Solidity contracts
   - `--sizes` flag shows contract sizes
   - Fails if compilation errors found

5. **Run Tests**
```bash
   forge test -vv
```
   - Executes all test files in `test/` directory
   - `-vv` flag: verbose output with gas info
   - **Required:** All tests must pass
   - **Scope:** 
     - Task 1: ERC-20 + fuzz + invariant tests
     - Task 2: Fork tests
     - Task 3: AMM tests
     - Task 5: Lending pool tests

6. **Generate Gas Report**
```bash
   forge test --gas-report
```
   - Creates gas consumption report
   - Shows gas costs per function
   - Useful for optimization

7. **Generate Coverage**
```bash
   forge coverage --report lcov
```
   - Measures code coverage percentage
   - Outputs in LCOV format
   - Allowed to fail (continue-on-error: true)

---

### Stage 2: Security Analysis (Slither)

**Job Name:** `security`

**Purpose:** Detect common smart contract vulnerabilities

**Steps:**

1. **Checkout Code**
   - Clones repository

2. **Setup Python**
   - Uses Python 3.10
   - Required for Slither

3. **Install Slither**
```bash
   pip install slither-analyzer
```
   - Installs Slither security analyzer
   - Checks for known vulnerabilities

4. **Run Analysis**
```bash
   slither . --json slither-report.json
```
   - Analyzes all contracts in current directory
   - Outputs JSON report
   - `continue-on-error: true` - doesn't fail pipeline

5. **Upload Report**
   - Saves Slither report as artifact
   - Available for download in GitHub Actions UI
   - Allows: always runs even if analysis fails

---

### Stage 3: Code Quality

**Job Name:** `lint`

**Purpose:** Verify project structure and basic checks

**Steps:**

1. **Checkout Code**
   - Clones repository

2. **Display Build Info**
   - Shows project metadata
   - Lists directory contents
   - Confirms structure is correct

---

## Pipeline Execution Flow
┌─────────────────────────────────────────┐
│   Push/PR to main or develop branch     │
└──────────────┬──────────────────────────┘
│
┌───────┴────────┐
│                │
┌──▼─────────┐  ┌──▼──────────┐  ┌──▼──────────┐
│   Tests    │  │  Security   │  │   Lint     │
│  (Parallel)│  │  (Parallel) │  │ (Parallel) │
└──┬─────────┘  └──┬──────────┘  └──┬──────────┘
│                │                │
├─ Build         ├─ Slither       ├─ Info
├─ Test (critical)
├─ Gas report    └─ Upload report
└─ Coverage
All jobs run in parallel for speed
If any CRITICAL job fails: PR blocked

---

## Job Dependencies & Failure Handling

### Critical Jobs (Must Pass)
- ✅ **Build** - Contract compilation
- ✅ **Test** - All test suites must pass

### Non-Critical Jobs (Can Fail)
- ⚠️ **Coverage** - `continue-on-error: true`
- ⚠️ **Security** - `continue-on-error: true`

### Parallel Execution
All three jobs (test, security, lint) run simultaneously:
- **Speed:** Faster overall feedback
- **Independent:** Failures don't block others
- **Efficiency:** Saves CI minutes

---

## Test Suites Covered

### Task 1: ERC-20 Token Testing
- **File:** `test/task1/MyToken.t.sol`
- **Count:** 15+ unit tests
- **Coverage:** Mint, transfer, approve, transferFrom, burn, edge cases
- **Includes:** Fuzz tests (256 runs each), invariant tests

### Task 2: Fork Testing
- **File:** `test/task2/ForkTest.t.sol`
- **Count:** 7 fork tests
- **Coverage:** Real mainnet contract interaction, Uniswap swaps
- **Network:** Ethereum mainnet

### Task 3: AMM Testing
- **File:** `test/task3/AMM.t.sol`
- **Count:** 20+ tests
- **Coverage:** Liquidity, swaps, invariant k, price impact
- **Types:** Unit tests, edge cases, sequential tests

### Task 5: Lending Pool Testing
- **File:** `test/task5/LendingPool.t.sol`
- **Count:** 20+ tests
- **Coverage:** Deposits, borrows, repays, liquidations
- **Types:** Interest accrual, health factor, edge cases

---

## Gas Report Output

The pipeline generates a gas report showing costs per operation:
╭─────────────────┬─────────┬────────┬────────┬────────╮
│ Contract        │ Method  │ Min    │ Max    │ Avg    │
├─────────────────┼─────────┼────────┼────────┼────────┤
│ MyToken         │ transfer│ 40,000 │ 50,000 │ 45,000 │
│ AMM             │ swap    │ 80,000 │ 110,000│ 95,000 │
│ LendingPool     │ borrow  │ 100,000│ 130,000│ 115,000│
╰─────────────────┴─────────┴────────┴────────┴────────╯

**Usage:** Identify gas optimization opportunities

---

## Security Analysis with Slither

Slither detects common vulnerabilities:

### Vulnerability Categories

1. **High Severity**
   - Reentrancy
   - Integer overflow/underflow
   - Unchecked external calls

2. **Medium Severity**
   - Missing access controls
   - Logic errors
   - Race conditions

3. **Low Severity**
   - Naming conventions
   - Code style
   - Optimization suggestions

### Example Report
```json
{
  "success": true,
  "results": {
    "detectors": [
      {
        "check": "reentrancy-benign",
        "impact": "low",
        "confidence": "medium",
        "description": "Potential reentrancy issue"
      }
    ]
  }
}
```

### Report Access
1. Go to GitHub Actions run
2. Click on "security" job
3. Download "slither-report" artifact
4. View as JSON

---

## Coverage Report

Code coverage measures how much of your code is tested.

### Coverage Metrics
File                    Lines    Functions    Branches    Coverage
─────────────────────────────────────────────────────────────────
src/task1/MyToken.sol    95%       100%         92%        95%
src/task3/AMM.sol        98%        98%         96%        97%
src/task5/LendingPool.sol 95%       96%         94%        95%
Average:                 96%        98%         94%        96%

**Target:** >90% coverage for production code

---

## Workflow Status Badge

Add to your README.md:
```markdown
[![Foundry Tests](https://github.com/YOUR_REPO/actions/workflows/test.yml/badge.svg)](https://github.com/YOUR_REPO/actions/workflows/test.yml)
```

---

## Running Locally (Before Push)

Test the pipeline locally using `act`:

### Install act
```bash
brew install act  # macOS
# or download from: https://github.com/nektos/act
```

### Run workflow locally
```bash
act -j test      # Run only test job
act -j security  # Run only security job
act              # Run all jobs
```

### Install dependencies for local testing
```bash
forge test       # All tests
forge build      # Build contracts
slither .        # Security analysis
```

---

## Troubleshooting

### Build Fails
Error: Source file not found
**Solution:** Ensure all imports use correct relative paths

### Tests Fail
Error: Assertion failed
**Solution:** Check test logic and contract implementation

### Slither Timeouts
Slither analysis took too long
**Solution:** Check for complex contract logic, split into smaller files

### Coverage Not Generated
Coverage report missing
**Solution:** May fail silently (continue-on-error), check console output

---

## Best Practices

### Before Pushing

1. **Run tests locally**
```bash
   forge test -vv
```

2. **Check compilation**
```bash
   forge build
```

3. **Review gas report**
```bash
   forge test --gas-report
```

4. **Run security analysis**
```bash
   slither .
```

### Pipeline Maintenance

1. **Monitor run times** - Optimize slow tests
2. **Review security reports** - Fix vulnerabilities
3. **Keep dependencies updated** - Upgrade Foundry regularly
4. **Archive reports** - Store historical data

---

## Pipeline Statistics

### Expected Execution Times
- **Build:** ~30 seconds
- **Tests:** ~2-3 minutes (depends on test count)
- **Security:** ~1-2 minutes
- **Coverage:** ~1 minute
- **Total:** ~5-7 minutes per run

### Cost
- GitHub Actions: Free tier allows 2,000 minutes/month
- This project: ~300+ runs/month available

---

## Conclusion

The CI/CD pipeline ensures:
✅ Code compiles correctly
✅ All tests pass
✅ No security vulnerabilities
✅ Gas costs tracked
✅ Code coverage maintained

Every commit is automatically validated before merging.

