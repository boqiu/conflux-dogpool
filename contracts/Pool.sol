// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SwappableV2.sol";
import "./Farmable.sol";
import "./TimeWindow.sol";
import "./IPool.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Pool is Initializable, SwappableV2, Farmable, AccessControlEnumerable, Ownable, IPool {
    using TimeWindow for TimeWindow.BalanceWindow;
    using SafeERC20 for IERC20;

    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");

    // pegged ETC
    IERC20 public minedToken;

    // time window for lock
    uint256 public lockSlotIntervalSecs;
    uint256 public lockWindowSize;

    mapping(address => TimeWindow.BalanceWindow) private _balances;

    // e.g. 10 means 10% ETH bonus
    uint8 public bonusPercentageETH = 10;

    uint256 public forceWithdrawRewards;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address swapRouter,
        address farmController,
        IERC20 minedToken_,
        uint256 lockSlotIntervalSecs_,
        uint256 lockWindowSize_
    ) public initializer {
        SwappableV2._initialize(swapRouter);

        address lpToken = SwappableV2._pairTokenETH(address(minedToken_));
        Farmable._initialize(farmController, lpToken);

        minedToken = minedToken_;
        lockSlotIntervalSecs = lockSlotIntervalSecs_;
        lockWindowSize = lockWindowSize_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        transferOwnership(msg.sender);
    }

    /**
     * @dev Dog pool operator deposits ETC into pool for specified `account`.
     */
    function deposit(uint256 amount, address account) public override onlyRole(DEPOSIT_ROLE) {
        require(amount > 0, "Pool: amount is zero");

        minedToken.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 amountETH, uint256 liquidity) = SwappableV2._addLiquidityETH(address(minedToken), amount);
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

    /**
     * @dev User withdraw unlocked assets.
     */
    function withdraw(address payable recipient) public override {
        uint256 amount = _balances[msg.sender].pop();
        if (amount == 0) {
            return;
        }

        if (_balances[msg.sender].tryClear()) {
            delete _balances[msg.sender];
        }

        Farmable._withdraw(msg.sender, amount, recipient);

        (uint256 amountToken, uint256 amountETH) = SwappableV2._removeLiquidityETH(address(minedToken), amount);

        if (amountToken > 0) {
            minedToken.safeTransfer(recipient, amountToken);
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
    function forceWithdraw(address recipient) public override {
        uint256 amount = _balances[msg.sender].clear();
        if (amount == 0) {
            return;
        }

        delete _balances[msg.sender];

        // rewards to contract
        forceWithdrawRewards += Farmable._withdraw(msg.sender, amount, address(0));

        (uint256 amountToken, uint256 amountETH) = _removeLiquidityETH(address(minedToken), amount);

        if (amountToken > 0) {
            minedToken.safeTransfer(recipient, amountToken);
        }

        emit ForceWithdraw(msg.sender, recipient, amount, amountToken, amountETH);
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
     * @dev Allow owner to set bonus ratio.
     */
    function setBonusPercentageETH(uint8 value) public onlyOwner {
        require(value <= 100, "Pool: value out of bound");
        bonusPercentageETH = value;
    }

    /**
     * @dev Allow owner to withdraw `amount` of native tokens to specified `recipient`.
     */
    function withdrawETH(uint256 amount, address payable recipient) public onlyOwner {
        require(amount <= address(this).balance, "Swappable: balance not enough");
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
