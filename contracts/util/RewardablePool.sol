// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev This contract aims to distribute reward to users based on the amount of staked tokens.
 */
contract RewardablePool {

    struct AccountInfo {
        uint256 amount;                 // token amount in pool
        uint256 accRewardPerShare;      // accumulative reward per share
    }

    mapping(address => AccountInfo) public accountInfos;

    uint256 public totalSupply;         // total amount of staked tokens in pool
    uint256 public accRewardPerShare;   // accumulative reward per share

    uint256 internal _weiPerShare = 1e18;

    function _initialize(IERC20Metadata token) internal {
        _weiPerShare = 10 ** token.decimals();
    }

    /**
     * @dev Update reward per share since last user operation.
     */
    function _updateReward(uint256 reward, AccountInfo storage account) private returns (uint256 accountReward) {
        if (reward > 0 && totalSupply > 0) {
            accRewardPerShare += reward * _weiPerShare / totalSupply;
        }

        // gas saving
        if (accRewardPerShare == account.accRewardPerShare) {
            return 0;
        }

        // calculate account reward
        accountReward = account.amount * (accRewardPerShare - account.accRewardPerShare) / _weiPerShare;

        account.accRewardPerShare = accRewardPerShare;
    }

    /**
     * @dev Deposits `amount` of tokens for specified `account` with desired `reward` since last user operation.
     */
    function _deposit(uint256 reward, address account, uint256 amount) internal virtual returns (uint256 accountReward) {
        AccountInfo storage info = accountInfos[account];

        accountReward = _updateReward(reward, info);

        if (amount > 0) {
            totalSupply += amount;
            info.amount += amount;
        }
    }

    /**
     * @dev Withdraw `amount` of tokens for specified `account` with desired `reward` since last user operation.
     */
    function _withdraw(uint256 reward, address account, uint256 amount) internal virtual returns (uint256 accountReward) {
        AccountInfo storage info = accountInfos[account];
        require(amount <= info.amount, "insufficient balance");

        accountReward = _updateReward(reward, info);

        if (amount > 0) {
            totalSupply -= amount;
            info.amount -= amount;
        }
    }

}
