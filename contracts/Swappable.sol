// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract Swappable is Ownable {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public router;

    constructor(address router_) {
        router = IUniswapV2Router02(router_);
    }

    receive() external payable {}

    function withdraw(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "balance not enough");
        payable(msg.sender).transfer(amount);
    }

    function _addLiquidityETH(address token, uint256 amount) internal returns (uint256, uint256) {
        address pair = IUniswapV2Factory(router.factory()).getPair(token, router.WETH());
        require(pair != address(0), "pair not found");

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();

        uint256 amountEthDesired = 0;
        if (IUniswapV2Pair(pair).token0() == token) {
            amountEthDesired = amount * reserve1 / reserve0;
        } else {
            amountEthDesired = amount * reserve0 / reserve1;
        }

        require(amountEthDesired <= address(this).balance, "balance not enough");

        IERC20(token).safeApprove(address(router), amount);

        (uint256 amountToken, uint256 amountEth, uint256 liquidity) = router.addLiquidityETH{value: amountEthDesired}(
            token, amount, amount, amountEthDesired, address(this), block.timestamp
        );

        require(amountToken == amount, "token amount mismatch");
        require(amountEth == amountEthDesired, "ETH amount mismatch");

        return (amountEth, liquidity);
    }

}
