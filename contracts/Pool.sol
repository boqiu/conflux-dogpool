// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Swappable.sol";
import "./TimeWindow.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract Pool is Swappable, AccessControlEnumerable {
    using TimeWindow for TimeWindow.BalanceWindow;
    using SafeERC20 for IERC20;

    event LiquidityEthAdded(
        address indexed operator,
        address indexed account,
        uint256 amountToken,
        uint256 amountEth,
        uint256 liquidity
    );

    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");

    // pegged ETC
    IERC20 public minedToken;

    // time window for lock
    uint256 public lockSlotIntervalSecs;
    uint256 public lockWindowSize;

    mapping(address => TimeWindow.BalanceWindow) private _balances;

    constructor(
        address router,
        IERC20 minedToken_,
        uint256 lockSlotIntervalSecs_,
        uint256 lockWindowSize_
    ) Swappable(router) {
        minedToken = minedToken_;
        lockSlotIntervalSecs = lockSlotIntervalSecs_;
        lockWindowSize = lockWindowSize_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Dog pool operator deposits ETC into pool for specified `account`.
     */
    function deposit(uint256 amount, address account) public onlyRole(DEPOSIT_ROLE) {
        require(amount > 0, "amount is zero");

        minedToken.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 amountEth, uint256 liquidity) = _addLiquidityETH(address(minedToken), amount);
        emit LiquidityEthAdded(msg.sender, account, amount, amountEth, liquidity);

        // TODO farm in advance to earn PPI

        _balances[account].push(liquidity, lockSlotIntervalSecs, lockWindowSize);
    }

    function balanceOf(address account)
        public view
        returns (uint256 totalBalance, uint256 unlockedBalance, TimeWindow.LockedBalance[] memory lockedBalances)
    {
        return _balances[account].balances();
    }

    /**
     * @dev User withdraw unlocked assets.
     */
    function withdraw(address recipient) public {
        uint256 amount = _balances[msg.sender].pop();

        if (_balances[msg.sender].clearIfEmpty()) {
            delete _balances[msg.sender];
        }

        // TODO withdraw from defi mining, and what fees and bonus to user?

        if (amount > 0) {
            // TODO transfer fee and bonus to user
            minedToken.safeTransferFrom(address(this), recipient, amount);
        }
    }

    // TODO user force withdraw locked assets.

}
