// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

/**
 * @dev Integrates with Swappi (Uniswap V2) to provide liquidity to earn transaction fees.
 */
contract SwappableV2 {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public v2Router;

    function _initialize(address router_) internal {
        v2Router = IUniswapV2Router02(router_);
    }

    function _pairTokenETH(address token) internal view returns (address pair) {
        pair = IUniswapV2Factory(v2Router.factory()).getPair(token, v2Router.WETH());
        require(pair != address(0), "Swappable: pair not found");
    }

    function _addLiquidityETH(address token, uint256 amount) internal returns (uint256 amountETH, uint256 liquidity) {
        address pair = _pairTokenETH(token);

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();

        uint256 amountETHDesired = 0;
        if (IUniswapV2Pair(pair).token0() == token) {
            amountETHDesired = amount * reserve1 / reserve0;
        } else {
            amountETHDesired = amount * reserve0 / reserve1;
        }

        require(amountETHDesired <= address(this).balance, "Swappable: balance not enough");

        IERC20(token).safeApprove(address(v2Router), amount);

        uint256 amountToken = 0;
        (amountToken, amountETH, liquidity) = v2Router.addLiquidityETH{value: amountETHDesired}(
            token, amount, amount, amountETHDesired, address(this), block.timestamp
        );

        require(amountToken == amount, "Swappable: token amount mismatch");
        require(amountETH == amountETHDesired, "Swappable: ETH amount mismatch");
    }

    function _removeLiquidityETH(address token, uint256 liquidity) internal returns (uint amountToken, uint amountETH) {
        address pair = _pairTokenETH(token);

        uint256 totalLiquidity = IUniswapV2Pair(pair).totalSupply();
        uint256 amountTokenMin = liquidity * IERC20(token).balanceOf(pair) / totalLiquidity;
        uint256 amountETHMin = liquidity * IERC20(v2Router.WETH()).balanceOf(pair) / totalLiquidity;

        IERC20(pair).safeApprove(address(v2Router), liquidity);

        (amountToken, amountETH) = v2Router.removeLiquidityETH(
            token, liquidity, amountTokenMin, amountETHMin, address(this), block.timestamp
        );

        require(amountToken == amountTokenMin, "Swappable: token amount mismatch");
        require(amountETH == amountETHMin, "Swappable: ETH amount mismatch");
    }

}
