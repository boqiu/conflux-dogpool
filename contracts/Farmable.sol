// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IFarm.sol";
import "./util/RewardablePool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Farmable is RewardablePool {
    using SafeERC20 for IERC20;

    event Reward(address indexed account, address indexed recipient, uint256 amount);

    IFarm public farm;
    IERC20 public rewardToken;      // e.g. PPI

    IERC20 public lpToken;          // e.g. ETC-CFX
    uint256 public poolId;          // pool index for deposit/withdraw

    function _initialize(address farm_, address lpToken_) internal {
        farm = IFarm(farm_);
        rewardToken = IERC20(farm.ppi());

        RewardablePool._initialize(IERC20Metadata(address(rewardToken)));

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

        require(address(lpToken) != address(0), "Farmable: LP token not found");
    }

    /**
     * @dev Query the reward of specified `account`.
     */
    function rewardOf(address account) public returns (uint256) {
        uint256 reward = farm.deposit(poolId, 0);
        return RewardablePool._deposit(reward, account, 0);
    }

    function _deposit(address account, uint256 liquidity) internal returns (uint256 accountReward) {
        if (liquidity > 0) {
            lpToken.safeApprove(address(farm), liquidity);
        }

        uint256 reward = farm.deposit(poolId, liquidity);

        accountReward = RewardablePool._deposit(reward, account, liquidity);
        if (accountReward > 0) {
            rewardToken.safeTransfer(account, accountReward);
            emit Reward(account, account, accountReward);
        }
    }

    function _withdraw(address account, uint256 liquidity, address rewardRecipient) internal returns (uint256 accountReward) {
        uint256 reward = farm.withdraw(poolId, liquidity);

        accountReward = RewardablePool._withdraw(reward, account, liquidity);
        if (accountReward > 0) {
            if (rewardRecipient != address(0)) {
                rewardToken.safeTransfer(rewardRecipient, accountReward);
            }

            emit Reward(account, rewardRecipient, accountReward);
        }
    }

}
