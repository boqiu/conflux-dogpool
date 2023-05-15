## Dog Pool Operator Functions

### Deposit ETC for users

```solidity
function deposit(uint256 amount, address account) public override onlyRole(DEPOSIT_ROLE)
```

- `amount`: amount of ETC to deposit. Note, `approve` required before deposit.
- `account`: account to deposit for.

## User Functions

### Query total LP in pool

```solidity
uint256 public totalShares
```

### Query user LP in pool

```solidity
function accountInfos(address account) public view returns (uint256 shares, uint256 accRewardPerShare)
```

### Query user balance

```solidity
function balanceOf(address account) public view override returns (
	uint256 totalBalance,
	uint256 unlockedBalance,
	LockedBalance[] memory lockedBalances
)

struct LockedBalance {
	uint256 amount;
	uint256 unlockTime;
}
```

### Query or claim user rewards

Note, please set the `from` address in `eth_call` to query account rewards.

```solidity
function claimReward(address recipient) public returns (uint256)
```

### Withdraw LP

```solidity
function withdraw(address payable recipient) public
```

### Force withdraw LP

Note, user will **NOT** receive CFX and PPI rewards if force withdraw locked LP.

```solidity
function forceWithdraw(address recipient) public
```

## Owner Functions

Withdraw native tokens (CFX):

```solidity
function withdrawETH(uint256 amount, address payable recipient) public onlyOwner
```

Query withdrawable rewards:
```solidity
uint256 public forceWithdrawRewards
```

Withdraw rewards (PPI):

```solidity
function withdrawRewards(uint256 amount, address recipient) public onlyOwner
```
