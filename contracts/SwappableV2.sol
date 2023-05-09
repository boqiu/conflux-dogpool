// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./swappi/SwappiLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/**
 * @dev Integrates with Swappi (Uniswap V2) to provide liquidity to earn transaction fees.
 */
contract SwappableV2 {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public v2Router;

    function _initialize(address router_) internal {
        v2Router = IUniswapV2Router02(router_);
    }

    function _addLiquidityETH(address token, uint256 amount) internal returns (uint amountETH, uint liquidity) {
        uint256 amountETHDesired = SwappiLibrary.getAmountETH(address(v2Router), token, amount);

        IERC20(token).safeApprove(address(v2Router), amount);

        uint256 amountToken = 0;
        (amountToken, amountETH, liquidity) = v2Router.addLiquidityETH{value: amountETHDesired}(
            token, amount, amount, amountETHDesired, address(this), block.timestamp
        );

        require(amountToken == amount, "SwappableV2: token amount mismatch");
        require(amountETH == amountETHDesired, "SwappableV2: ETH amount mismatch");
    }

    function _removeLiquidityETH(address token, uint256 liquidity) internal returns (uint amountToken, uint amountETH) {
        address pair = SwappiLibrary.getPairETH(address(v2Router), token);

        uint256 totalLiquidity = IUniswapV2Pair(pair).totalSupply();
        uint256 amountTokenMin = liquidity * IERC20(token).balanceOf(pair) / totalLiquidity;
        uint256 amountETHMin = liquidity * IERC20(v2Router.WETH()).balanceOf(pair) / totalLiquidity;

        IERC20(pair).safeApprove(address(v2Router), liquidity);

        (amountToken, amountETH) = v2Router.removeLiquidityETH(
            token, liquidity, amountTokenMin, amountETHMin, address(this), block.timestamp
        );

        require(amountToken == amountTokenMin, "SwappableV2: token amount mismatch");
        require(amountETH == amountETHMin, "SwappableV2: ETH amount mismatch");
    }

}
