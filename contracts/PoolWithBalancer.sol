// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "./swappi/ISwappiRouter01.sol";
import "./swappi/SwappiLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PoolWithBalancer is Pool {
    using SafeERC20 for IERC20;

    ISwappiRouter01 public router;

    function initialize(
        address router_,
        address farmController,
        address minedToken,
        uint256 lockSlotIntervalSecs,
        uint256 lockWindowSize
    ) public initializer {
        Pool._initialize(router_, farmController, minedToken, lockSlotIntervalSecs, lockWindowSize);

        router = ISwappiRouter01(router_);
    }

    function _addLiquidityETH(address token, uint256 amount) internal override returns (uint256 amountETH, uint256 liquidity) {
        // Always add liquidity according to the current reserves of pair token.
        // This way depends on the market maker to work fine. Otherwise, much less
        // or more CFX will be used to provide liquidity.
        //
        // TODO once price oracle for ETC token available, we could provide liquidity
        // with fixed weight, e.g. 98:2.
        uint256 amountETHDesired = SwappiLibrary.getAmountETH(address(router), token, amount);

        IERC20(token).safeApprove(address(router), amount);

        uint256 amountToken = 0;
        // assume that pair already created and no need to specify weights
        // TODO specify `minLiquidity` to avoid large slippage
        (amountToken, amountETH, liquidity) = router.addLiquidityETH{value: amountETHDesired}(
            token, [uint256(0), uint256(0)], amount, 0, address(this), block.timestamp
        );
    }

    function _removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal override returns (uint256 amountToken, uint256 amountETH) {
        // `approve` not required
        // address pair = SwappiLibrary.getPairETH(address(router), token);
        // IERC20(pair).safeApprove(address(router), liquidity);

        (amountToken, amountETH) = router.removeLiquidityETH(
            token, liquidity, amountTokenMin, amountETHMin, address(this), deadline
        );
    }

}
