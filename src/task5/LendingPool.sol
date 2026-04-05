// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LendingPool {
    IERC20 public token;

    // Constants
    uint256 public constant LTV = 75; // 75% Loan-to-Value ratio
    uint256 public constant INTEREST_RATE = 5; // 5% annual interest rate
    uint256 public constant LIQUIDATION_BONUS = 10; // 10% liquidation bonus

    // User positions
    struct Position {
        uint256 collateral; // Amount of token deposited as collateral
        uint256 borrowed; // Amount of token borrowed
        uint256 lastInterestUpdate; // Timestamp of last interest accrual
    }

    mapping(address => Position) public positions;
    uint256 public totalCollateral;
    uint256 public totalBorrowed;

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Invalid token");
        token = IERC20(_token);
    }

    // ==================== DEPOSIT & WITHDRAWAL ====================

    /**
     * @dev Deposit tokens as collateral
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer tokens from user to contract
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Update user's collateral
        positions[msg.sender].collateral += amount;
        totalCollateral += amount;

        // Initialize last interest update if first time
        if (positions[msg.sender].lastInterestUpdate == 0) {
            positions[msg.sender].lastInterestUpdate = block.timestamp;
        }

        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Withdraw collateral (only if health factor > 1)
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(positions[msg.sender].collateral >= amount, "Insufficient collateral");

        // Accrue interest first
        accrueInterest(msg.sender);

        // Check if withdrawal would make position unhealthy
        uint256 collateralAfter = positions[msg.sender].collateral - amount;
        uint256 borrowed = positions[msg.sender].borrowed;

        if (borrowed > 0) {
            uint256 requiredCollateral = (borrowed * 100) / LTV;
            require(collateralAfter >= requiredCollateral, "Withdrawal would make position unhealthy");
        }

        // Update collateral
        positions[msg.sender].collateral -= amount;
        totalCollateral -= amount;

        // Transfer tokens to user
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    // ==================== BORROW & REPAY ====================

    /**
     * @dev Borrow tokens (max 75% of collateral)
     * @param amount Amount of tokens to borrow
     */
    function borrow(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");

        // Accrue interest first
        accrueInterest(msg.sender);

        uint256 collateral = positions[msg.sender].collateral;
        uint256 maxBorrow = (collateral * LTV) / 100;
        uint256 currentBorrowed = positions[msg.sender].borrowed;

        require(currentBorrowed + amount <= maxBorrow, "Exceeds LTV limit");
        require(amount <= token.balanceOf(address(this)) - totalCollateral, "Insufficient pool liquidity");

        // Update borrowed amount
        positions[msg.sender].borrowed += amount;
        totalBorrowed += amount;

        // Transfer tokens to user
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit Borrow(msg.sender, amount);
    }

    /**
     * @dev Repay borrowed tokens (partial or full)
     * @param amount Amount of tokens to repay
     */
    function repay(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");

        // Accrue interest first
        accrueInterest(msg.sender);

        uint256 borrowed = positions[msg.sender].borrowed;
        require(borrowed > 0, "No debt to repay");
        require(amount <= borrowed, "Repay amount exceeds borrowed amount");

        // Transfer tokens from user to contract
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Update borrowed amount
        positions[msg.sender].borrowed -= amount;
        totalBorrowed -= amount;

        emit Repay(msg.sender, amount);
    }

    // ==================== INTEREST ACCRUAL ====================

    /**
     * @dev Accrue interest on borrowed amount
     * @param user User address
     */
    function accrueInterest(address user) public {
        Position storage pos = positions[user];

        if (pos.borrowed == 0) {
            return; // No interest to accrue
        }

        uint256 timePassed = block.timestamp - pos.lastInterestUpdate;
        if (timePassed == 0) {
            return; // No time passed
        }

        // Interest calculation: borrowed * (rate / 100) * (timePassed / 365 days)
        uint256 interestAccrued = (pos.borrowed * INTEREST_RATE * timePassed) / (365 days * 100);

        pos.borrowed += interestAccrued;
        totalBorrowed += interestAccrued;
        pos.lastInterestUpdate = block.timestamp;
    }

    // ==================== HEALTH FACTOR & LIQUIDATION ====================

    /**
     * @dev Calculate health factor for a user
     * Health Factor = (Collateral * 100) / (Borrowed * LTV)
     * HF > 1 = Safe, HF < 1 = Liquidatable
     */
    function getHealthFactor(address user) public view returns (uint256) {
        Position memory pos = positions[user];

        if (pos.borrowed == 0) {
            return type(uint256).max; // Infinite HF if no debt
        }

        // Health Factor = (collateral * 100) / (borrowed * 100 / LTV)
        //              = (collateral * LTV) / borrowed
        return (pos.collateral * LTV) / pos.borrowed;
    }

    /**
     * @dev Check if a user is liquidatable (health factor < 1)
     */
    function isLiquidatable(address user) public view returns (bool) {
        return getHealthFactor(user) < 100; // HF < 1 means numerator < denominator/100
    }

    /**
     * @dev Liquidate an undercollateralized position
     * @param borrower Address of borrower to liquidate
     * @param repayAmount Amount of debt to repay
     */
    function liquidate(address borrower, uint256 repayAmount) public {
        require(isLiquidatable(borrower), "Position is not liquidatable");
        require(repayAmount > 0, "Repay amount must be greater than 0");

        Position storage pos = positions[borrower];
        require(repayAmount <= pos.borrowed, "Repay amount exceeds debt");

        // Calculate collateral to seize (repay amount + 10% bonus)
        uint256 collateralToSeize = repayAmount + (repayAmount * LIQUIDATION_BONUS) / 100;
        require(collateralToSeize <= pos.collateral, "Insufficient collateral to seize");

        // Transfer repay amount from liquidator to pool
        require(token.transferFrom(msg.sender, address(this), repayAmount), "Transfer failed");

        // Update borrower position
        pos.borrowed -= repayAmount;
        pos.collateral -= collateralToSeize;
        totalBorrowed -= repayAmount;
        totalCollateral -= collateralToSeize;

        // Transfer seized collateral + bonus to liquidator
        require(token.transfer(msg.sender, collateralToSeize), "Transfer failed");

        emit Liquidate(msg.sender, borrower, repayAmount);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @dev Get user's position details
     */
    function getPosition(address user) public view returns (uint256 collateral, uint256 borrowed) {
        Position memory pos = positions[user];
        return (pos.collateral, pos.borrowed);
    }

    /**
     * @dev Get pool statistics
     */
    function getPoolStats() public view returns (uint256 _totalCollateral, uint256 _totalBorrowed) {
        return (totalCollateral, totalBorrowed);
    }

    /**
     * @dev Calculate maximum borrow amount for a user
     */
    function getMaxBorrow(address user) public view returns (uint256) {
        uint256 collateral = positions[user].collateral;
        uint256 currentBorrowed = positions[user].borrowed;
        uint256 maxBorrow = (collateral * LTV) / 100;
        
        if (currentBorrowed >= maxBorrow) {
            return 0;
        }
        return maxBorrow - currentBorrowed;
    }

    /**
     * @dev Get available liquidity in pool
     */
    function getAvailableLiquidity() public view returns (uint256) {
        return token.balanceOf(address(this)) - totalCollateral;
    }
}
