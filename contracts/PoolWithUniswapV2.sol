// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "./swappi/SwappiLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract PoolWithUniswapV2 is Pool {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public router;

    // e.g. 10 means 10% ETH bonus
    uint8 public bonusPercentageETH = 10;

    function initialize(
        address router_,
        address farmController,
        address minedToken,
        uint256 lockSlotIntervalSecs,
        uint256 lockWindowSize
    ) public initializer {
        Pool._initialize(router_, farmController, minedToken, lockSlotIntervalSecs, lockWindowSize);

        router = IUniswapV2Router02(router_);
    }

    /**
     * @dev Allow owner to set bonus ratio.
     */
    function setBonusPercentageETH(uint8 value) public onlyOwner {
        require(value <= 100, "PoolWithUniswapV2: value out of bound");
        bonusPercentageETH = value;
    }

    function _addLiquidityETH(address token, uint256 amount) internal override returns (uint256 amountETH, uint256 liquidity) {
        uint256 amountETHDesired = SwappiLibrary.getAmountETH(address(router), token, amount);

        IERC20(token).safeApprove(address(router), amount);

        uint256 amountToken = 0;
        (amountToken, amountETH, liquidity) = router.addLiquidityETH{value: amountETHDesired}(
            token, amount, amount, amountETHDesired, address(this), block.timestamp
        );
    }

    function _removeLiquidityETH(address token, uint256 liquidity) internal override returns (uint256 amountToken, uint256 amountETH) {
        address pair = SwappiLibrary.getPairETH(address(router), token);
        IERC20(pair).safeApprove(address(router), liquidity);

        (amountToken, amountETH) = router.removeLiquidityETH(
            token, liquidity, 0, 0, address(this), block.timestamp
        );

        amountETH = amountETH * bonusPercentageETH / 100;
    }

}
