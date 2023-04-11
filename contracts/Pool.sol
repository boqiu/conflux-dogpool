// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TimeWindow.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pool is AccessControlEnumerable, Ownable {
    using TimeWindow for TimeWindow.BalanceWindow;
    using SafeERC20 for IERC20;

    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");

    // pegged ETC
    IERC20 public minedToken;

    // time window for lock
    uint256 public lockSlotIntervalSecs;
    uint256 public lockWindowSize;

    mapping(address => TimeWindow.BalanceWindow) private _balances;

    constructor(IERC20 minedToken_, uint256 lockSlotIntervalSecs_, uint256 lockWindowSize_) {
        minedToken = minedToken_;
        lockSlotIntervalSecs = lockSlotIntervalSecs_;
        lockWindowSize = lockWindowSize_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Deposit CFX to provide liquidity in Swappi.
     */
    receive() external payable {}

    /**
     * @dev Allow owner to withdraw CFX in case of an emergency.
     */
    function withdraw(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "balance not enough");
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Dog pool operator deposits ETC into pool for specified `account`.
     */
    function deposit(uint256 amount, address account) public onlyRole(DEPOSIT_ROLE) {
        require(amount > 0, "amount is zero");
        minedToken.safeTransferFrom(msg.sender, address(this), amount);
        _balances[account].push(amount, lockSlotIntervalSecs, lockWindowSize);
        // TODO leverage Swappi or Goledo to provide liquidity, earn fees and defi mining
        // it's up to conflux funds to provide cfx
        // both LP & farming
        // goledo in advance?
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
