// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// USDC Interface (ERC-20)
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// Uniswap V2 Router Interface
interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract ForkTest is Test {
    // Real mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    IERC20 usdc;
    IERC20 usdt;
    IERC20 weth;
    IUniswapV2Router router;

    function setUp() public {
        // Fork Ethereum mainnet at a specific block
        vm.createSelectFork("https://eth.llamarpc.com");

        // Initialize interfaces
        usdc = IERC20(USDC);
        usdt = IERC20(USDT);
        weth = IERC20(WETH);
        router = IUniswapV2Router(UNISWAP_V2_ROUTER);
    }

    // ==================== TEST 1: Read USDC Total Supply ====================
    function test_ReadUSDCTotalSupply() public view {
        uint256 totalSupply = usdc.totalSupply();

        // USDC typically has billions of tokens in circulation
        assertTrue(totalSupply > 0);
        assertTrue(totalSupply > 1_000_000_000 * 10 ** 6); // More than 1 billion USDC

        console.log("USDC Total Supply:", totalSupply);
        console.log(
            "USDC Total Supply (in millions):",
            totalSupply / 10 ** 6 / 1_000_000
        );
    }

    // ==================== TEST 2: Read USDT Total Supply ====================
    function test_ReadUSDTTotalSupply() public view {
        uint256 totalSupply = usdt.totalSupply();

        assertTrue(totalSupply > 0);
        assertTrue(totalSupply > 1_000_000_000 * 10 ** 6);

        console.log("USDT Total Supply:", totalSupply);
        console.log(
            "USDT Total Supply (in millions):",
            totalSupply / 10 ** 6 / 1_000_000
        );
    }

    // ==================== TEST 3: Simulate Uniswap V2 Swap (USDC -> WETH) ====================
    function test_UNiswapV2SwapUSDCToWETH() public {
        uint256 amountIn = 1000 * 10 ** 6; // 1000 USDC

        // Get a whale address that holds USDC (for testing purposes)
        address usdcWhale = 0xf977814E90Da44BfA03339670389A86F01cd61C9; // Binance address

        // Impersonate the whale to get USDC
        vm.prank(usdcWhale);
        usdc.transfer(address(this), amountIn);

        // Verify we received USDC
        assertEq(usdc.balanceOf(address(this)), amountIn);

        // Approve Uniswap V2 Router to spend USDC
        usdc.approve(UNISWAP_V2_ROUTER, amountIn);

        // Create swap path: USDC -> WETH
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;

        // Get expected output amount
        uint[] memory amountsOut = router.getAmountsOut(amountIn, path);
        uint expectedWETH = amountsOut[1];

        console.log("Input USDC:", amountIn / 10 ** 6);
        console.log("Expected WETH output:", expectedWETH / 10 ** 18);

        // Execute swap with slippage protection (allow 5% slippage)
        uint minAmountOut = (expectedWETH * 95) / 100;

        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        );

        // Verify swap was successful
        uint wethReceived = amounts[amounts.length - 1];
        assertTrue(wethReceived >= minAmountOut);
        assertEq(weth.balanceOf(address(this)), wethReceived);

        console.log("Actual WETH received:", wethReceived / 10 ** 18);
        console.log("Slippage:", (expectedWETH - wethReceived) / 10 ** 18);
    }

    // ==================== TEST 4: Simulate Uniswap V2 Swap (WETH -> USDC) ====================
    function test_UNiswapV2SwapWETHToUSDC() public {
        uint256 amountIn = 10 * 10 ** 18; // 10 WETH

        // Get a whale address that holds WETH
        address wethWhale = 0xe78388B4CE79068e89Bf8Aa6E48E2FB81B9D56cC; // WETH holder

        // Impersonate the whale to get WETH
        vm.prank(wethWhale);
        weth.transfer(address(this), amountIn);

        // Verify we received WETH
        assertEq(weth.balanceOf(address(this)), amountIn);

        // Approve Uniswap V2 Router to spend WETH
        weth.approve(UNISWAP_V2_ROUTER, amountIn);

        // Create swap path: WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        // Get expected output amount
        uint[] memory amountsOut = router.getAmountsOut(amountIn, path);
        uint expectedUSDC = amountsOut[1];

        console.log("Input WETH:", amountIn / 10 ** 18);
        console.log("Expected USDC output:", expectedUSDC / 10 ** 6);

        // Execute swap with slippage protection (allow 5% slippage)
        uint minAmountOut = (expectedUSDC * 95) / 100;

        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        );

        // Verify swap was successful
        uint usdcReceived = amounts[amounts.length - 1];
        assertTrue(usdcReceived >= minAmountOut);
        assertEq(usdc.balanceOf(address(this)), usdcReceived);

        console.log("Actual USDC received:", usdcReceived / 10 ** 6);
        console.log("Slippage:", (expectedUSDC - usdcReceived) / 10 ** 6);
    }

    // ==================== TEST 5: Test vm.createSelectFork ====================
    function test_CreateSelectFork() public view {
        // This test demonstrates vm.createSelectFork
        // It was already used in setUp() to fork mainnet

        uint256 forkId = vm.activeFork();
        assertTrue(forkId > 0);

        console.log("Active fork ID:", forkId);
        console.log("Current block number:", block.number);
        console.log("Current chain ID:", block.chainid);
    }

    // ==================== TEST 6: Test vm.rollFork ====================
    function test_RollFork() public {
        uint256 initialBlock = block.number;
        console.log("Initial block:", initialBlock);

        // Roll forward to a block 100 blocks ahead
        vm.rollFork(initialBlock + 100);

        uint256 newBlock = block.number;
        console.log("New block:", newBlock);

        assertEq(newBlock, initialBlock + 100);

        // USDC total supply should remain the same (or slightly increase due to interest)
        uint256 totalSupply = usdc.totalSupply();
        assertTrue(totalSupply > 0);
        console.log("USDC Total Supply at rolled block:", totalSupply);
    }

    // ==================== TEST 7: Test Multiple Swaps ====================
    function test_MultipleUniswapSwaps() public {
        uint256 amountIn = 500 * 10 ** 6; // 500 USDC

        // Get USDC from whale
        address usdcWhale = 0xf977814E90Da44BfA03339670389A86F01cd61C9;
        vm.prank(usdcWhale);
        usdc.transfer(address(this), amountIn * 2); // Get 1000 USDC total

        // First swap: USDC -> WETH
        usdc.approve(UNISWAP_V2_ROUTER, amountIn);
        address[] memory path1 = new address[](2);
        path1[0] = USDC;
        path1[1] = WETH;

        uint[] memory amounts1 = router.getAmountsOut(amountIn, path1);
        uint wethReceived = amounts1[1];

        router.swapExactTokensForTokens(
            amountIn,
            (wethReceived * 95) / 100,
            path1,
            address(this),
            block.timestamp + 300
        );

        console.log(
            "Swap 1 - USDC to WETH: Received",
            weth.balanceOf(address(this)) / 10 ** 18,
            "WETH"
        );

        // Second swap: WETH -> USDC (back to where we started)
        weth.approve(UNISWAP_V2_ROUTER, wethReceived);
        address[] memory path2 = new address[](2);
        path2[0] = WETH;
        path2[1] = USDC;

        uint[] memory amounts2 = router.getAmountsOut(wethReceived, path2);
        uint usdcReceived = amounts2[1];

        router.swapExactTokensForTokens(
            wethReceived,
            (usdcReceived * 95) / 100,
            path2,
            address(this),
            block.timestamp + 300
        );

        console.log(
            "Swap 2 - WETH back to USDC: Received",
            usdc.balanceOf(address(this)) / 10 ** 6,
            "USDC"
        );

        // We should have some USDC left (less than original due to slippage and fees)
        assertTrue(usdc.balanceOf(address(this)) > 0);
    }
}
