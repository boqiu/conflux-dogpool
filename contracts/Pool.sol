// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Swappable.sol";
import "./TimeWindow.sol";
import "./util/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract Pool is Initializable, Swappable, AccessControlEnumerable {
    using TimeWindow for TimeWindow.BalanceWindow;
    using SafeERC20 for IERC20;

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
        uint256 amountETH,
        uint256 bonusETH
    );

    event ForceWithdraw(
        address indexed operator,
        address indexed recipient,
        uint256 liquidity,
        uint256 amountToken,
        uint256 amountETH
    );

    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");

    // pegged ETC
    IERC20 public minedToken;

    // time window for lock
    uint256 public lockSlotIntervalSecs;
    uint256 public lockWindowSize;

    mapping(address => TimeWindow.BalanceWindow) private _balances;

    // e.g. 20 means 20% ETH bonus
    uint8 public bonusPercentageETH = 20;

    function initialize(
        address router,
        IERC20 minedToken_,
        uint256 lockSlotIntervalSecs_,
        uint256 lockWindowSize_
    ) public {
        Initializable._initialize();
        Swappable._initialize(router);

        minedToken = minedToken_;
        lockSlotIntervalSecs = lockSlotIntervalSecs_;
        lockWindowSize = lockWindowSize_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setBonusPercentageETH(uint8 value) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(value <= 100, "value out of bound");
        bonusPercentageETH = value;
    }

    /**
     * @dev Dog pool operator deposits ETC into pool for specified `account`.
     */
    function deposit(uint256 amount, address account) public onlyRole(DEPOSIT_ROLE) {
        require(amount > 0, "amount is zero");

        minedToken.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 amountETH, uint256 liquidity) = _addLiquidityETH(address(minedToken), amount);
        emit Deposit(msg.sender, account, amount, amountETH, liquidity);

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
    function withdraw(address payable recipient) public {
        uint256 amount = _balances[msg.sender].pop();
        if (amount == 0) {
            return;
        }

        if (_balances[msg.sender].tryClear()) {
            delete _balances[msg.sender];
        }

        (uint256 amountToken, uint256 amountETH) = _removeLiquidityETH(address(minedToken), amount);

        if (amountToken > 0) {
            minedToken.safeTransferFrom(address(this), recipient, amountToken);
        }

        uint256 bonusETH = amountETH * bonusPercentageETH / 100;
        if (bonusETH > 0) {
            recipient.transfer(bonusETH);
        }

        emit Withdraw(msg.sender, recipient, amount, amountToken, amountETH, bonusETH);
    }

    /**
     * @dev Allow user to force withdraw locked assets without bonus.
     */
    function forceWithdraw(address payable recipient) public {
        uint256 amount = _balances[msg.sender].clear();
        if (amount == 0) {
            return;
        }

        delete _balances[msg.sender];

        (uint256 amountToken, uint256 amountETH) = _removeLiquidityETH(address(minedToken), amount);

        if (amountToken > 0) {
            minedToken.safeTransferFrom(address(this), recipient, amountToken);
        }

        emit ForceWithdraw(msg.sender, recipient, amount, amountToken, amountETH);
    }

}
