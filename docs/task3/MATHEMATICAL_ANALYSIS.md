# AMM Mathematical Analysis: Constant Product Formula

## Table of Contents
1. Constant Product Formula Derivation
2. Fee Impact on Invariant k
3. Impermanent Loss Analysis
4. Price Impact Calculation
5. Comparison to Uniswap V2

---

## 1. Constant Product Formula Derivation

### 1.1 Basic Concept

An Automated Market Maker (AMM) allows users to trade directly from a liquidity pool without requiring a counterparty. The constant product formula, popularized by Uniswap V2, ensures market equilibrium through a mathematical invariant.

### 1.2 The Formula

**Core Invariant:**
x * y = k

Where:
- `x` = reserve of token A
- `y` = reserve of token B
- `k` = constant product (invariant)

### 1.3 Derivation from First Principles

**Definition:** The total value in the pool must be conserved (before fees).

For a swap of token A for token B:
- Input: `Δx` amount of token A
- Output: `Δy` amount of token B (to be determined)

**Before swap:**
x * y = k

**After swap:**
(x + Δx) * (y - Δy) = k

**Solving for Δy (output amount):**
(x + Δx) * (y - Δy) = x * y
(x + Δx) * (y - Δy) = x * y
xy - xΔy + Δxy - Δx*Δy = xy
-xΔy + Δxy - Δx*Δy = 0
Δxy = xΔy + Δx*Δy
Δx*y = Δy * (x + Δx)
Δy = (Δx * y) / (x + Δx)

**Final Output Formula:**
Δy = (Δx * y) / (x + Δx)

This is the **core constant product AMM formula**. It guarantees that after any trade, the product of reserves is maintained.

### 1.4 Why It Works

The constant product formula creates a **hyperbolic bonding curve**:
y = k / x

**Key properties:**
1. **Bounded output:** As Δx increases, Δy increases but at a decreasing rate
2. **Slippage:** Larger trades experience higher price impact
3. **No limit orders:** AMM always has liquidity at any price
4. **Self-adjusting price:** Price automatically adjusts based on demand

**Example:**
Initial: x = 1000, y = 1000, k = 1,000,000
Trader wants to swap 100 units of A for B:
Δy = (100 * 1000) / (1000 + 100)
Δy = 100,000 / 1,100
Δy = 90.91 units of B
New state: x = 1100, y = 909.09, k = 1,000,000 ✓

---

## 2. Fee Impact on Invariant k

### 2.1 Fee Mechanics in Uniswap V2

Uniswap V2 charges a **0.3% fee** on every swap. This fee stays in the pool and accrues to liquidity providers.

**Fee Calculation:**
amountInWithFee = amountIn * (1000 - feePercentage) / 1000
amountInWithFee = amountIn * (1000 - 3) / 1000
amountInWithFee = amountIn * 997 / 1000

### 2.2 Impact on k

**Without fees:** k would remain constant (k = k')

**With fees:** The invariant k actually **increases** over time.

**Proof:**

Before swap:
k = x * y

Swap with 0.3% fee:
amountInWithFee = Δx * 997/1000
Δy_output = (amountInWithFee * y) / (x + amountInWithFee)
= (Δx * 997/1000 * y) / (x + Δx * 997/1000)

After swap:
x' = x + Δx                    (full amount received by pool)
y' = y - Δy_output             (reduced by actual output)
k' = x' * y'
= (x + Δx) * (y - Δy_output)

Since only 99.7% of the input is used for calculation:
k' > k
(x + Δx) * (y - Δy_output) > x * y

**Because:** The 0.3% fee that remains in the pool increases k.

### 2.3 Fee Accrual Over Time

**After n swaps with fees:**
k_final = k_initial * (1 + fee_collected)

This is why LPs benefit from fees—their share of k grows over time, even without adding more liquidity.

**Example with 0.3% fee:**
Initial: x = 1000, y = 1000, k = 1,000,000
After 100 swaps of 10 units each at 0.3% fee:
Cumulative fee collected ≈ 0.3% * 1000 ≈ 3 units worth
k_final ≈ 1,000,030 (increased by ~0.003%)

### 2.4 LP Reward Model

LPs earn fees proportional to:
1. Their share of the pool (LP balance / total LP supply)
2. Total volume traded through the pool
3. 0.3% of every swap

**Annual Fee Estimate:**
Annual Fees = Total Volume Traded * 0.003
LP Reward = (LP Balance / Total LP) * Annual Fees

---

## 3. Impermanent Loss Analysis

### 3.1 What is Impermanent Loss?

**Impermanent Loss (IL)** is the opportunity cost that LPs incur when providing liquidity to an AMM, compared to simply holding the tokens.

When a token's price changes significantly, LPs lose value due to the AMM's automatic rebalancing.

### 3.2 IL Formula Derivation

**Setup:**
- Liquidity provider deposits: `x₀` of token A, `y₀` of token B
- Initial price: `p₀ = y₀ / x₀`
- Price changes to: `p₁`

**LP's position after price change:**
After rebalancing:
x₁ = sqrt(x₀ * y₀ / p₁)  ≈ √(k/p₁)
y₁ = sqrt(x₀ * y₀ * p₁)  ≈ √(k*p₁)

**LP's portfolio value:**
Value_LP = x₁ + y₁ * p₁

**HODL value (if they just held):**
Value_HODL = x₀ + y₀ * p₁

**Impermanent Loss:**
IL = Value_HODL - Value_LP
= (x₀ + y₀ * p₁) - (x₁ + y₁ * p₁)

### 3.3 IL for 2x Price Change

**Example:** Initial price is 1:1 (x₀ = y₀ = 1000)

Price doubles: p₁ = 2 * p₀

**LP's position after price change:**
x₁ = √(1000 * 1000 / 2) = √(500,000) ≈ 707.1
y₁ = √(1000 * 1000 * 2) = √(2,000,000) ≈ 1414.2

**Comparison:**
Initial deposit: 1000 A + 1000 B (at price 1:1)
= 1000 + 1000 = 2000 in value
After 2x price increase:
HODL value:     1000 A + 1000 B = 1000 + 2000 = 3000
LP value:       707.1 A + 1414.2 B = 707.1 + 2828.4 = 3535.5
Wait, that's more? Let me recalculate...
Actually:
LP value = 707.1 * 1 + 1414.2 * 2 = 707.1 + 2828.4 = 3535.5
HODL value = 1000 * 1 + 1000 * 2 = 1000 + 2000 = 3000
LP value > HODL value?? That's incorrect.
Let me reconsider: price in terms of A per B.

**Correct calculation:**

Initial price: 1 A = 1 B

After price change: 1 A = 2 B (A doubled in value)
Initial LP deposit:
x₀ = 1000 A
y₀ = 1000 B
Value = 1000 + 1000 * 1 = 2000 in A-equivalent
After price increases (A doubles):
k = 1000 * 1000 = 1,000,000
x₁ = √(1,000,000 / 2) ≈ 707.1 A
y₁ = √(1,000,000 * 2) ≈ 1414.2 B
LP value = 707.1 A + 1414.2 B * (1/2) A = 707.1 + 707.1 = 1414.2 A-equivalent
HODL value = 1000 A + 1000 B * (1/2) A = 1000 + 500 = 1500 A-equivalent
Impermanent Loss = 1500 - 1414.2 = 85.8 A-equivalent (5.7% loss)

### 3.4 IL Percentage Formula

For a price change of factor `r` (new price / old price):
IL% = (2 * √r / (1 + r)) - 1
For r = 2 (2x price increase):
IL% = (2 * √2 / (1 + 2)) - 1
= (2 * 1.414 / 3) - 1
= 2.828 / 3 - 1
= 0.9428 - 1
= -0.0572 = -5.72%
For r = 4 (4x price increase):
IL% = (2 * √4 / (1 + 4)) - 1
= (2 * 2 / 5) - 1
= 4/5 - 1
= -0.20 = -20%

**IL increases with price volatility:**

| Price Change | IL % Loss |
|---|---|
| 1.25x | -0.6% |
| 1.5x | -1.7% |
| 2x | -5.7% |
| 3x | -13.4% |
| 4x | -20% |
| 5x | -25.5% |
| 10x | -47.7% |

### 3.5 IL Recovery Through Fees

**Important:** IL is offset by trading fees!
Total LP Profit = Fee Income - Impermanent Loss

For a 2x price movement with 5.7% IL:
- Fees must exceed 5.7% of the pool value to break even
- High-volume, low-volatility pairs are most profitable
- High-volatility pairs require high fee income to be worthwhile

---

## 4. Price Impact Calculation

### 4.1 Definition

**Price Impact** is the difference between the spot price and the execution price for a specific trade.

It represents how much worse a trader's execution is due to the trade's size relative to the pool.

### 4.2 Price Impact Formula

**Spot price (before trade):**
P_spot = y / x

**Execution price (after trade):**
P_execution = Δy / Δx

**Price Impact:**
PI = (P_spot - P_execution) / P_spot

### 4.3 Price Impact as Function of Trade Size

**Given:**
Δx = amount trading in
Δy = (Δx * y) / (x + Δx)  [output with constant product]

**Price Impact:**
P_spot = y / x
P_execution = [(Δx * y) / (x + Δx)] / Δx = y / (x + Δx)
PI = (y/x - y/(x+Δx)) / (y/x)
= ((y/x) - (y/(x+Δx))) / (y/x)
= (1 - x/(x+Δx))
= Δx / (x + Δx)

**Key insight:** Price impact depends on the ratio of trade size to pool reserves.

### 4.4 Examples

**Pool: 1000 A : 1000 B**

Trade 10 A:
PI = 10 / (1000 + 10) = 10/1010 = 0.99% price impact

Trade 100 A:
PI = 100 / (1000 + 100) = 100/1100 = 9.09% price impact

Trade 500 A (50% of pool):
PI = 500 / (1000 + 500) = 500/1500 = 33.33% price impact

**Larger trades = Higher price impact**

### 4.5 Optimization Strategies

To minimize price impact:

1. **Use larger pools** - Higher reserves → lower impact
2. **Split orders** - Multi-hop through different pairs
3. **Off-peak trading** - When pool has higher liquidity
4. **Time trades strategically** - Avoid high slippage times

---

## 5. Comparison to Uniswap V2

### 5.1 Similarities

| Aspect | Our AMM | Uniswap V2 |
|--------|---------|-----------|
| Constant product formula | ✅ | ✅ |
| 0.3% fee structure | ✅ | ✅ |
| LP token representation | ✅ | ✅ |
| Slippage protection | ✅ | ✅ |
| Price impact calculation | ✅ | ✅ |
| Impermanent loss | ✅ | ✅ |
| Square root LP calculation | ✅ | ✅ |

### 5.2 Differences

| Feature | Our AMM | Uniswap V2 |
|---------|---------|-----------|
| **Code complexity** | ~300 lines | ~2000+ lines |
| **Factory pattern** | ❌ | ✅ |
| **Router contract** | ❌ | ✅ (separate) |
| **Multi-hop swaps** | ❌ | ✅ |
| **Flash swaps** | ❌ | ✅ |
| **Price oracle** | ❌ | ✅ (TWAP) |
| **Access controls** | ❌ | ✅ |
| **Governance** | ❌ | ✅ |
| **Gas optimization** | Basic | Highly optimized |
| **ERC-20 compatibility** | Full | Full |

### 5.3 Uniswap V2 Advanced Features (Not Implemented)

**1. Factory Pattern**
```solidity
// Uniswap creates new pairs through factory
UniswapV2Factory.createPair(tokenA, tokenB)
```
Benefit: Deterministic pair addresses, reduced gas

**2. Router Contract**
```solidity
// Uniswap separates swap logic from pool
Router02.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline)
```
Benefit: Enable multi-hop swaps, better UX

**3. Flash Swaps**
```solidity
// Borrow tokens without collateral, repay in same transaction
pair.swap(amount0Out, amount1Out, to, data)
```
Benefit: Arbitrage opportunities, complex strategies

**4. Time-Weighted Average Price (TWAP) Oracle**
```solidity
// Track cumulative prices for oracle
uint32 blockTimestamp = uint32(block.timestamp % 2**32);
uint224 reserve0Cumulative = uint224(...);
```
Benefit: Reliable price data for other contracts

**5. Gas Optimizations**
- Bitpacking for reserves
- Optimized swap calculations
- Efficient token transfer patterns

---

## 6. Key Insights

### 6.1 Fundamental Principles

1. **Constant Product is fundamental**
   - x * y = k ensures no arbitrage
   - Bonding curve creates natural slippage
   - Self-adjusting price mechanism

2. **Fees drive LP returns**
   - 0.3% fee accumulates in k
   - Offsets impermanent loss
   - Fee income is the LP's reward

3. **Impermanent loss is real but manageable**
   - IL increases with volatility
   - Offset by trading fees
   - Best for stablecoin pairs

4. **Price impact scales with trade size**
   - Impact = Δx / (x + Δx)
   - Larger pools = lower impact
   - Incentivizes pool liquidity

### 6.2 Design Trade-offs

| Choice | Benefit | Cost |
|--------|---------|------|
| Constant product | Simple, mathematically proven | High slippage for large trades |
| 0.3% fee | LPs compensated, aligns incentives | Cost for traders |
| Fixed fee | Predictable, simple | May not optimize for market |
| LP tokens | Ownership tracking, composability | Added complexity |

---

## 7. Conclusion

The constant product formula (x * y = k) is an elegant solution to the AMM design problem. By maintaining a mathematical invariant, it ensures:

1. **Market equilibrium** without order books
2. **Continuous liquidity** at any price
3. **Fair pricing** through transparent math
4. **LP incentives** through fee accumulation
5. **Trader protection** via slippage protection

While impermanent loss is a real risk, the fee structure compensates LPs, making AMMs viable and profitable in many market conditions.

Uniswap V2 extends these core principles with advanced features like routers, flash swaps, and oracles, but the fundamental constant product model remains the foundation of AMM success.

---

## References

- Uniswap V2 Whitepaper: https://uniswap.org/whitepaper.pdf
- Automated Market Makers (AMMs): https://en.wikipedia.org/wiki/Automated_market_maker
- Constant Product Formula Analysis: https://www.paradigm.xyz
EEOF
