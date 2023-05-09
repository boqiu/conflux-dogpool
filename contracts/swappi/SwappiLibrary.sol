// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

library SwappiLibrary {

    /**
     * @dev Returns the address of pair for `token` and `WETH`.
     */
    function getPairETH(address router, address token) internal view returns (address pair) {
        address factory = IUniswapV2Router02(router).factory();
        address weth = IUniswapV2Router02(router).WETH();
        pair = IUniswapV2Factory(factory).getPair(token, weth);
        require(pair != address(0), "SwappiLibrary: pair not found");
    }

    /**
     * @dev Returns the amount of ETH to add liquidity with `amount` of `token`.
     */
    function getAmountETH(address router, address token, uint256 amount) internal view returns (uint256 amountETH) {
        address pair = getPairETH(router, token);
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "SwappiLibrary: no liquidity provided");
        amountETH = IUniswapV2Pair(pair).token0() == token
            ? amount * reserve1 / reserve0
            : amount * reserve0 / reserve1;
        require(amountETH <= address(this).balance, "SwappiLibrary: balance not enough");
    }

}
