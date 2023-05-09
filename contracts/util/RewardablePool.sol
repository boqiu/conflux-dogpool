// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev This contract aims to distribute reward to users based on the staked shares.
 */
contract RewardablePool {

    struct AccountInfo {
        uint256 shares;                 // shares in pool
        uint256 accRewardPerShare;      // accumulative reward per share
    }

    mapping(address => AccountInfo) public accountInfos;

    uint256 public totalShares;         // total shares in pool
    uint256 public accRewardPerShare;   // accumulative reward per share

    uint256 internal _weiPerShare = 1e18;

    function _initialize(IERC20Metadata shareToken) internal {
        _weiPerShare = 10 ** shareToken.decimals();
    }

    /**
     * @dev Update reward per share since last user operation.
     */
    function _updateReward(uint256 reward, AccountInfo storage account) private returns (uint256 accountReward) {
        if (reward > 0 && totalShares > 0) {
            accRewardPerShare += reward * _weiPerShare / totalShares;
        }

        // gas saving
        if (accRewardPerShare == account.accRewardPerShare) {
            return 0;
        }

        // calculate account reward
        accountReward = account.shares * (accRewardPerShare - account.accRewardPerShare) / _weiPerShare;

        account.accRewardPerShare = accRewardPerShare;
    }

    /**
     * @dev Deposits `shares` of tokens for specified `account` with desired `reward` since last user operation.
     */
    function _deposit(uint256 reward, address account, uint256 shares) internal virtual returns (uint256 accountReward) {
        AccountInfo storage info = accountInfos[account];

        accountReward = _updateReward(reward, info);

        if (shares > 0) {
            totalShares += shares;
            info.shares += shares;
        }
    }

    /**
     * @dev Withdraw `shares` of tokens for specified `account` with desired `reward` since last user operation.
     */
    function _withdraw(uint256 reward, address account, uint256 shares) internal virtual returns (uint256 accountReward) {
        AccountInfo storage info = accountInfos[account];
        require(shares <= info.shares, "RewardablePool: insufficient balance");

        accountReward = _updateReward(reward, info);

        if (shares > 0) {
            totalShares -= shares;
            info.shares -= shares;
        }
    }

}
