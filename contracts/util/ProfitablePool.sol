// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev This contract aims to distribute profit to users based on the amount of staked tokens.
 */
contract ProfitablePool {

    struct AccountInfo {
        uint256 amount;                 // token amount in pool
        uint256 accProfitPerShare;      // accumulative profit per share
    }

    mapping(address => AccountInfo) public accountInfos;

    uint256 public totalSupply;         // total amount of staked tokens in pool
    uint256 public accProfitPerShare;   // accumulative profit per share

    uint256 internal _weiPerShare = 1e18;

    /**
     * @dev Update profit per share since last user operation.
     */
    function _updateProfit(uint256 profit, AccountInfo storage account) private returns (uint256 accountProfit) {
        if (profit > 0 && totalSupply > 0) {
            accProfitPerShare += profit * _weiPerShare / totalSupply;
        }

        // gas saving
        if (accProfitPerShare == account.accProfitPerShare) {
            return 0;
        }

        // calculate account profit
        accountProfit = account.amount * (accProfitPerShare - account.accProfitPerShare) / _weiPerShare;

        account.accProfitPerShare = accProfitPerShare;
    }

    /**
     * @dev Deposits `amount` of tokens for specified `account` with desired `profit` since last user operation.
     */
    function _deposit(uint256 profit, address account, uint256 amount) internal virtual returns (uint256 accountProfit) {
        AccountInfo storage info = accountInfos[account];

        accountProfit = _updateProfit(profit, info);

        if (amount > 0) {
            totalSupply += amount;
            info.amount += amount;
        }
    }

    /**
     * @dev Withdraw `amount` of tokens for specified `account` with desired `profit` since last user operation.
     */
    function _withdraw(uint256 profit, address account, uint256 amount) internal virtual returns (uint256 accountProfit) {
        AccountInfo storage info = accountInfos[account];
        require(amount <= info.amount, "insufficient balance");

        accountProfit = _updateProfit(profit, info);

        if (amount > 0) {
            totalSupply -= amount;
            info.amount -= amount;
        }
    }

}
