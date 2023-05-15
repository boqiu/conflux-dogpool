// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TimeWindow.sol";

interface IPool {

    event Deposit(
        address indexed operator,
        address indexed account,
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    event Withdraw(
        address indexed operator,
        address indexed recipient,
        uint256 liquidity,
        uint256 amountToken,
        uint256 amountETH
    );

    event ForceWithdraw(
        address indexed operator,
        address indexed recipient,
        uint256 liquidity,
        uint256 amountToken
    );

    function deposit(uint256 amount, address account) external;

    function balanceOf(address account) external view returns (
        uint256 totalBalance,
        uint256 unlockedBalance,
        TimeWindow.LockedBalance[] memory lockedBalances
    );

    function withdraw(address payable recipient) external;
    function forceWithdraw(address recipient) external;

}
