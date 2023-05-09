// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./swappi/ISwappiRouter01.sol";
import "./swappi/SwappiLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Integrates with Swappi (Balancer model) to provide liquidity to earn transaction fees.
 */
contract SwappableWeighted {
    using SafeERC20 for IERC20;

    ISwappiRouter01 public balancerRouter;

    function _initialize(address router_) internal {
        balancerRouter = ISwappiRouter01(router_);
    }

    function _addLiquidityETH(address token, uint256 amount) internal returns (uint amountETH, uint liquidity) {
        // TODO always add liquidity with fixed ratio or dynamic ratio?
        uint256 amountETHDesired = SwappiLibrary.getAmountETH(address(balancerRouter), token, amount);

        IERC20(token).safeApprove(address(balancerRouter), amount);

        uint256 amountToken = 0;
        // assume that pair already created and no need to specify weights
        (amountToken, amountETH, liquidity) = balancerRouter.addLiquidityETH{value: amountETHDesired}(
            token, [uint256(0), uint256(0)], amount, 0, address(this), block.timestamp
        );

        require(amountToken == amount, "SwappableWeighted: token amount mismatch");
        require(amountETH == amountETHDesired, "SwappableWeighted: ETH amount mismatch");
    }

    function _removeLiquidityETH(address token, uint256 liquidity) internal returns (uint amountToken, uint amountETH) {
        address pair = SwappiLibrary.getPairETH(address(balancerRouter), token);
        IERC20(pair).safeApprove(address(balancerRouter), liquidity);

        (amountToken, amountETH) = balancerRouter.removeLiquidityETH(
            token, liquidity, 0, 0, address(this), block.timestamp
        );
    }

}
