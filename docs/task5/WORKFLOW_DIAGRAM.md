# Lending Pool Workflow Diagram

## User Flow: Deposit → Borrow → Repay → Withdraw

### Step 1: Deposit (Collateral)
User                           LendingPool
|                                 |
|-- approve(pool, amount) ------->|
|                                 |
|-- deposit(amount) ------------->|
|                                 |
|<-- Collateral Added ------------|
|     Position updated
|     balanceOf decreases
|     collateral increases

**What happens:**
- User deposits tokens as collateral
- Pool records deposit in `positions[user].collateral`
- Tokens transferred from user to pool
- Health factor initialized

---

### Step 2: Borrow (Against Collateral)
User                           LendingPool
|                                 |
|-- borrow(amount) ------------->|
|                                 |
|   Check: amount <= (collateral * LTV) / 100
|                                 |
|<-- Tokens Transferred ---------|
|     borrowed amount updated
|     Interest timer started

**Constraints:**
- Can only borrow up to 75% of collateral (LTV ratio)
- Health Factor = (collateral * LTV) / borrowed
- Must maintain HF > 1 at all times

**Maximum Borrow:**
max_borrow = (collateral * 75) / 100

---

### Step 3: Interest Accrual (Automatic)
Time passes...
LendingPool (accrueInterest function)
|
|-- Calculate: interest = borrowed * rate * time / (365 days * 100)
|-- Update: borrowed += interest
|-- Increase total_borrowed
|-- Set lastInterestUpdate = now

**Interest Rate:** 5% per year

**Formula:**
interest_accrued = (borrowed_amount * 5 * time_elapsed) / (365 days * 100)

---

### Step 4: Repay (Full or Partial)
User                           LendingPool
|                                 |
|-- approve(pool, amount) ------->|
|                                 |
|-- repay(amount) ------------->|
|                                 |
|   Accrue interest first
|   Verify: amount <= borrowed
|                                 |
|<-- Debt Reduced --------------|
|     borrowed -= amount
|     Tokens transferred to pool

**Two scenarios:**
1. **Partial Repay:** User pays part of the debt
2. **Full Repay:** User pays all debt including interest

---

### Step 5: Withdraw (Collateral)
User                           LendingPool
|                                 |
|-- withdraw(amount) ----------->|
|                                 |
|   Check health factor:
|   remaining_collateral >= (borrowed * 100) / LTV
|                                 |
|   If HF < 1 after withdrawal:
|   REJECT (position would be unsafe)
|                                 |
|<-- Collateral Returned --------|
|     collateral -= amount
|     Tokens transferred to user

**Safety Check:**
remaining_collateral = collateral - withdraw_amount
required_collateral = (borrowed * 100) / LTV
require(remaining_collateral >= required_collateral)

---

## Liquidation Flow

### Scenario: User Becomes Undercollateralized
Time passes, interest accrues...
Alice's Position:
collateral: 1000
borrowed: 750 (was at 75% LTV)

50 interest accrued
= borrowed now: 800 (exceeds 75% LTV!)

Health Factor = (1000 * 75) / 800 = 93.75
Status: LIQUIDATABLE (HF < 100)

### Liquidation Execution
Liquidator                     LendingPool                    Alice
|                              |                           |
|-- approve(pool, 200) ------->|                           |
|                              |                           |
|-- liquidate(alice, 200) ---->|                           |
|                              |                           |
|                         Check: isLiquidatable(alice)
|                              |
|                         Calculate collateral to seize:
|                         seized = 200 + (200 * 10%)
|                              = 220 tokens
|                              |
|                         Transfer 200 from liquidator
|<-- 220 tokens transferred ----|
|                              |
|                         Update Alice's position:
|                         - borrowed -= 200
|                         - collateral -= 220
|                              |
|                         Alice loses collateral!

**Liquidation Mechanics:**
- **Repay Amount:** 200 tokens (paid by liquidator)
- **Collateral Seized:** 200 + (200 × 10%) = 220 tokens
- **Liquidation Bonus:** 10% extra collateral as reward for liquidator
- **Result:** Alice's position becomes safe, liquidator profits

---

## Health Factor States
┌─────────────────────────────────────────┐
│         Health Factor States             │
├─────────────────────────────────────────┤
│                                          │
│  HF > 100 (HF > 1)                      │
│  ✅ SAFE - Can withdraw & borrow        │
│                                          │
│  HF = 100 (HF = 1)                      │
│  ⚠️  AT RISK - Maximum LTV reached      │
│                                          │
│  HF < 100 (HF < 1)                      │
│  ❌ LIQUIDATABLE - Position unsafe      │
│                                          │
│  HF = ∞                                  │
│  ✅ NO DEBT - Cannot be liquidated      │
│                                          │
└─────────────────────────────────────────┘

---

## Key Formulas

### Health Factor
HF = (collateral * LTV) / borrowed
Example: collateral=1000, borrowed=750, LTV=75
HF = (1000 * 75) / 750 = 100 ✓ (at threshold)

### Maximum Borrow
max_borrow = (collateral * LTV) / 100
Example: collateral=1000, LTV=75
max_borrow = (1000 * 75) / 100 = 750

### Interest Accrual
interest = (borrowed * rate * time) / (365 days * 100)
Example: borrowed=500, rate=5%, time=1 year
interest = (500 * 5 * 365 days) / (365 days * 100) = 25 tokens

### Liquidation Seized Collateral
seized = repay_amount + (repay_amount * bonus%)
Example: repay=200, bonus=10%
seized = 200 + 20 = 220

---

## Complete User Journey

Alice deposits 1000 tokens as collateral
State: collateral=1000, borrowed=0, HF=∞
Alice borrows 750 tokens (75% of 1000)
State: collateral=1000, borrowed=750, HF=100
30 days pass, 5% annual interest accrues
Interest: (750 * 5 * 30) / (365 * 100) ≈ 3.08 tokens
State: collateral=1000, borrowed=753.08, HF≈99.6
Alice becomes liquidatable (HF < 100)
Bob liquidates 200 tokens of Alice's debt
Bob pays 200, receives 220 (200 + 10% bonus)
Alice loses: 220 collateral
Alice's position after liquidation:
collateral=780, borrowed=553.08, HF≈105
Alice repays remaining 553.08 tokens
State: collateral=780, borrowed=0, HF=∞
Alice withdraws all 780 remaining collateral
Final state: Everything withdrawn
