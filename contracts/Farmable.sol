// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IFarm.sol";
import "./util/ProfitablePool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Farmable is ProfitablePool {
    using SafeERC20 for IERC20;

    event Reward(address indexed account, address indexed recipient, uint256 amount);

    IFarm public farm;
    IERC20 public rewardToken;      // e.g. PPI

    IERC20 public lpToken;          // e.g. ETC-CFX
    uint256 public poolId;          // pool index for deposit/withdraw

    function _initialize(address farm_, address lpToken_) internal {
        farm = IFarm(farm_);
        rewardToken = IERC20(farm.ppi());

        // initialize pool id
        uint256 len = farm.poolLength();
        for (uint256 i = 0; i < len; i++) {
            IFarm.PoolInfo memory info = farm.poolInfo(i);
            if (info.token == lpToken_) {
                lpToken = IERC20(lpToken_);
                poolId = i;
                break;
            }
        }

        require(address(lpToken) != address(0), "LP token not found");
    }

    /**
     * @dev Query the rewards of specified `account`.
     */
    function rewardsOf(address account) public returns (uint256) {
        uint256 profit = farm.deposit(poolId, 0);
        return ProfitablePool._deposit(profit, account, 0);
    }

    function _deposit(address account, uint256 liquidity) internal returns (uint256 accountProfit) {
        if (liquidity > 0) {
            lpToken.safeApprove(address(farm), liquidity);
        }

        uint256 profit = farm.deposit(poolId, liquidity);

        accountProfit = ProfitablePool._deposit(profit, account, liquidity);
        if (accountProfit > 0) {
            rewardToken.safeTransfer(account, accountProfit);
            emit Reward(account, account, accountProfit);
        }
    }

    function _withdraw(address account, uint256 liquidity, address profitRecipient) internal returns (uint256 accountProfit) {
        uint256 profit = farm.withdraw(poolId, liquidity);

        accountProfit = ProfitablePool._withdraw(profit, account, liquidity);
        if (accountProfit > 0) {
            if (profitRecipient != address(0)) {
                rewardToken.safeTransfer(profitRecipient, accountProfit);
            }

            emit Reward(account, profitRecipient, accountProfit);
        }
    }

}
