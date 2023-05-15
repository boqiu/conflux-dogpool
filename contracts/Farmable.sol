// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./swappi/IFarm.sol";
import "./util/RewardablePool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Integrates with Swappi farming to mine PPI.
 */
contract Farmable is RewardablePool {
    using SafeERC20 for IERC20;

    event Reward(address indexed account, uint256 amount);
    event Claim(address indexed account, address indexed recipient, uint256 amount);

    IFarm public farm;
    IERC20 public rewardToken;      // e.g. PPI

    IERC20 public lpToken;          // e.g. ETC-ETH
    uint256 public poolId;          // pool index for deposit/withdraw

    mapping(address => uint256) public pendingRewards;

    uint256 public forceWithdrawRewards;

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
     * @dev Claim reward.
     */
    function claimReward(address recipient) public returns (uint256) {
        uint256 reward = farm.deposit(poolId, 0);
        uint256 accountReward = RewardablePool._deposit(reward, msg.sender, 0);

        if (pendingRewards[msg.sender] > 0) {
            accountReward += pendingRewards[msg.sender];
            delete pendingRewards[msg.sender];
        }

        if (accountReward > 0) {
            rewardToken.safeTransfer(recipient, accountReward);
            emit Claim(msg.sender, recipient, accountReward);
        }

        return accountReward;
    }

    function _deposit(address account, uint256 liquidity) internal {
        if (liquidity > 0) {
            lpToken.safeApprove(address(farm), liquidity);
        }

        uint256 reward = farm.deposit(poolId, liquidity);

        uint256 accountReward = RewardablePool._deposit(reward, account, liquidity);

        if (accountReward > 0) {
            pendingRewards[account] += accountReward;
            emit Reward(account, accountReward);
        }
    }

    function _withdraw(address account, uint256 liquidity, address rewardRecipient) internal {
        uint256 reward = farm.withdraw(poolId, liquidity);

        uint256 accountReward = RewardablePool._withdraw(reward, account, liquidity);

        if (accountReward > 0) {
            emit Reward(account, accountReward);
        }

        if (pendingRewards[account] > 0) {
            accountReward += pendingRewards[account];
            delete pendingRewards[msg.sender];
        }

        if (accountReward > 0) {
            if (rewardRecipient == address(0)) {
                forceWithdrawRewards += accountReward;
            } else {
                rewardToken.safeTransfer(rewardRecipient, accountReward);
                emit Claim(account, rewardRecipient, accountReward);
            }
        }
    }

}
