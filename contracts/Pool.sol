// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPool.sol";
import "./Farmable.sol";
import "./swappi/SwappiLibrary.sol";
import "./TimeWindow.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

abstract contract Pool is Initializable, Farmable, AccessControlEnumerable, Ownable, IPool {
    using TimeWindow for TimeWindow.BalanceWindow;
    using SafeERC20 for IERC20;

    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");

    // pegged ETC
    IERC20 public minedToken;

    // time window for lock
    uint256 public lockSlotIntervalSecs;
    uint256 public lockWindowSize;

    mapping(address => TimeWindow.BalanceWindow) private _balances;

    function _initialize(
        address router,
        address farmController,
        address minedToken_,
        uint256 lockSlotIntervalSecs_,
        uint256 lockWindowSize_
    ) internal {
        address lpToken = SwappiLibrary.getPairETH(router, minedToken_);
        Farmable._initialize(farmController, lpToken);

        minedToken = IERC20(minedToken_);
        lockSlotIntervalSecs = lockSlotIntervalSecs_;
        lockWindowSize = lockWindowSize_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        transferOwnership(msg.sender);
    }

    function _addLiquidityETH(address token, uint256 amount) internal virtual returns (uint256 amountETH, uint256 liquidity);

    /**
     * @dev Dog pool operator deposits ETC into pool for specified `account`.
     */
    function deposit(uint256 amount, address account) public override onlyRole(DEPOSIT_ROLE) {
        require(amount > 0, "Pool: amount is zero");
        require(account != address(0), "Pool: account is empty address");

        minedToken.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 amountETH, uint256 liquidity) = _addLiquidityETH(address(minedToken), amount);
        emit Deposit(msg.sender, account, amount, amountETH, liquidity);

        Farmable._deposit(account, liquidity);

        _balances[account].push(liquidity, lockSlotIntervalSecs, lockWindowSize);
    }

    /**
     * @dev Query account balance, including locked and unlocked balances.
     */
    function balanceOf(address account) public view override returns (
        uint256 totalBalance,
        uint256 unlockedBalance,
        TimeWindow.LockedBalance[] memory lockedBalances
    ) {
        return _balances[account].balances();
    }

    function _removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal virtual returns (uint256 amountToken, uint256 amountETH);

    /**
     * @dev User withdraw unlocked assets.
     */
    function withdraw(
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address payable to,
        uint256 deadline
    ) public override {
        require(liquidity > 0, "Pool: liquidity is zero");

        _balances[msg.sender].pop(liquidity);

        if (_balances[msg.sender].tryClear()) {
            delete _balances[msg.sender];
        }

        Farmable._withdraw(msg.sender, liquidity, to);

        (uint256 amountToken, uint256 amountETH) = _removeLiquidityETH(
            address(minedToken), liquidity, amountTokenMin, amountETHMin, deadline
        );

        if (amountToken > 0) {
            minedToken.safeTransfer(to, amountToken);
        }

        if (amountETH > 0) {
            to.transfer(amountETH);
        }

        emit Withdraw(msg.sender, to, liquidity, amountToken, amountETH);
    }

    /**
     * @dev Allow user to force withdraw locked assets without bonus.
     */
    function forceWithdraw(
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public override {
        require(liquidity > 0, "Pool: liquidity is zero");

        uint256 amount = _balances[msg.sender].clear();
        require(liquidity == amount, "Pool: liquidity mismatch");

        delete _balances[msg.sender];

        // rewards to contract
        Farmable._withdraw(msg.sender, liquidity, address(0));

        (uint256 amountToken,) = _removeLiquidityETH(
            address(minedToken), liquidity, amountTokenMin, amountETHMin, deadline
        );

        if (amountToken > 0) {
            minedToken.safeTransfer(to, amountToken);
        }

        emit ForceWithdraw(msg.sender, to, amount, amountToken);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////
    //
    // Owner functions
    //
    /////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Allow owner/anyone to deposit native tokens into this contract to provide liquidity.
     */
    receive() external payable {}

    /**
     * @dev Allow owner to withdraw `amount` of native tokens to specified `recipient`.
     */
    function withdrawETH(uint256 amount, address payable recipient) public onlyOwner {
        require(amount <= address(this).balance, "Pool: balance not enough");
        recipient.transfer(amount);
    }

    /**
     * @dev Allow owner to withdraw rewards from user force withdrawal.
     */
    function withdrawRewards(uint256 amount, address recipient) public onlyOwner {
        require(amount <= forceWithdrawRewards, "Pool: insufficient rewards");
        forceWithdrawRewards -= amount;
        Farmable.rewardToken.safeTransfer(recipient, amount);
    }

}
