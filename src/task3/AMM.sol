// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface ILPToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract AMM {
    // Token addresses
    IERC20 public tokenA;
    IERC20 public tokenB;
    ILPToken public lpToken;

    // Pool reserves
    uint256 public reserveA;
    uint256 public reserveB;

    // Fee (0.3% = 3 in basis points / 1000)
    uint256 public constant FEE = 3; // 0.3%
    uint256 public constant FEE_DENOMINATOR = 1000;

    // Events
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swap(address indexed trader, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB, address _lpToken) {
        require(_tokenA != address(0), "Invalid token A");
        require(_tokenB != address(0), "Invalid token B");
        require(_lpToken != address(0), "Invalid LP token");
        require(_tokenA != _tokenB, "Tokens must be different");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = ILPToken(_lpToken);
    }

    // ==================== LIQUIDITY FUNCTIONS ====================

    /**
     * @dev Add liquidity to the pool
     * @param amountA Amount of token A to add
     * @param amountB Amount of token B to add
     * @param minLpOut Minimum LP tokens to receive (slippage protection)
     */
    function addLiquidity(uint256 amountA, uint256 amountB, uint256 minLpOut) public returns (uint256 lpMinted) {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than 0");

        // Transfer tokens from user to AMM
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "TokenA transfer failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "TokenB transfer failed");

        uint256 newReserveA = reserveA + amountA;
        uint256 newReserveB = reserveB + amountB;

        // Calculate LP tokens to mint
        if (lpToken.totalSupply() == 0) {
            // First liquidity provider: mint sqrt(amountA * amountB)
            lpMinted = sqrt(amountA * amountB);
        } else {
            // Subsequent providers: mint based on smaller proportion
            uint256 lpFromA = (amountA * lpToken.totalSupply()) / reserveA;
            uint256 lpFromB = (amountB * lpToken.totalSupply()) / reserveB;
            lpMinted = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        require(lpMinted >= minLpOut, "Slippage protection: insufficient LP output");

        // Mint LP tokens
        lpToken.mint(msg.sender, lpMinted);

        // Update reserves
        reserveA = newReserveA;
        reserveB = newReserveB;

        emit LiquidityAdded(msg.sender, amountA, amountB, lpMinted);

        return lpMinted;
    }

    /**
     * @dev Remove liquidity from the pool
     * @param lpAmount Amount of LP tokens to burn
     * @param minAmountA Minimum token A to receive
     * @param minAmountB Minimum token B to receive
     */
    function removeLiquidity(uint256 lpAmount, uint256 minAmountA, uint256 minAmountB) 
        public 
        returns (uint256 amountA, uint256 amountB) 
    {
        require(lpAmount > 0, "LP amount must be greater than 0");
        require(lpToken.balanceOf(msg.sender) >= lpAmount, "Insufficient LP balance");

        uint256 totalLp = lpToken.totalSupply();

        // Calculate amounts to return (proportional to pool)
        amountA = (lpAmount * reserveA) / totalLp;
        amountB = (lpAmount * reserveB) / totalLp;

        require(amountA >= minAmountA, "Slippage protection: insufficient A output");
        require(amountB >= minAmountB, "Slippage protection: insufficient B output");

        // Burn LP tokens
        lpToken.burn(msg.sender, lpAmount);

        // Update reserves
        reserveA -= amountA;
        reserveB -= amountB;

        // Transfer tokens to user
        require(tokenA.transfer(msg.sender, amountA), "TokenA transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "TokenB transfer failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);

        return (amountA, amountB);
    }

    // ==================== SWAP FUNCTIONS ====================

    /**
     * @dev Get output amount for a swap (with fee)
     * @param amountIn Input amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public 
        pure 
        returns (uint256) 
    {
        require(amountIn > 0, "Input amount must be greater than 0");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        // Apply fee: amountInWithFee = amountIn * (1000 - 3) / 1000
        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - FEE)) / FEE_DENOMINATOR;

        // Calculate output using constant product formula: k = x * y
        // y_out = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee)
        uint256 numerator = reserveOut * amountInWithFee;
        uint256 denominator = reserveIn + amountInWithFee;

        return numerator / denominator;
    }

    /**
     * @dev Swap token A for token B
     * @param amountAIn Amount of token A to swap
     * @param minBOut Minimum token B to receive (slippage protection)
     */
    function swapAForB(uint256 amountAIn, uint256 minBOut) public returns (uint256 amountBOut) {
        require(amountAIn > 0, "Amount must be greater than 0");

        // Transfer token A from user to AMM
        require(tokenA.transferFrom(msg.sender, address(this), amountAIn), "TokenA transfer failed");

        // Calculate output amount
        amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        require(amountBOut >= minBOut, "Slippage protection: insufficient output");
        require(amountBOut <= reserveB, "Insufficient reserve B");

        // Update reserves
        reserveA += amountAIn;
        reserveB -= amountBOut;

        // Transfer token B to user
        require(tokenB.transfer(msg.sender, amountBOut), "TokenB transfer failed");

        emit Swap(msg.sender, address(tokenA), amountAIn, amountBOut);

        return amountBOut;
    }

    /**
     * @dev Swap token B for token A
     * @param amountBIn Amount of token B to swap
     * @param minAOut Minimum token A to receive (slippage protection)
     */
    function swapBForA(uint256 amountBIn, uint256 minAOut) public returns (uint256 amountAOut) {
        require(amountBIn > 0, "Amount must be greater than 0");

        // Transfer token B from user to AMM
        require(tokenB.transferFrom(msg.sender, address(this), amountBIn), "TokenB transfer failed");

        // Calculate output amount
        amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        require(amountAOut >= minAOut, "Slippage protection: insufficient output");
        require(amountAOut <= reserveA, "Insufficient reserve A");

        // Update reserves
        reserveB += amountBIn;
        reserveA -= amountAOut;

        // Transfer token A to user
        require(tokenA.transfer(msg.sender, amountAOut), "TokenA transfer failed");

        emit Swap(msg.sender, address(tokenB), amountBIn, amountAOut);

        return amountAOut;
    }

    // ==================== HELPER FUNCTIONS ====================

    /**
     * @dev Calculate square root (Babylonian method)
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /**
     * @dev Get current k (should remain constant or increase due to fees)
     */
    function getK() public view returns (uint256) {
        return reserveA * reserveB;
    }
}
