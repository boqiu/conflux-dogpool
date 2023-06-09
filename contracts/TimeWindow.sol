// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library TimeWindow {
    using SafeMath for uint256;

    struct TimeoutWindow {
        // start index, inclusive
        uint256 start;
        // end index, exclusive
        uint256 end;
        // index => slot end time
        mapping(uint256 => uint256) endTimes;
        // index => slot expiration time
        mapping(uint256 => uint256) expirationTimes;
    }

    function empty(TimeoutWindow storage window) internal view returns (bool) {
        return window.start == window.end;
    }

    function expired(TimeoutWindow storage window, uint256 index) internal view returns (bool) {
        require(index >= window.start && index < window.end, "TimeoutWindow: index out of bound");
        return window.expirationTimes[index] <= block.timestamp;
    }

    function pushBackIfEnded(TimeoutWindow storage window, uint256 slotIntervalSecs, uint256 numSlots) internal returns (uint256, bool) {
        require(slotIntervalSecs > 0, "TimeoutWindow: slot interval is zero");
        require(numSlots > 0, "TimeoutWindow: num slots is zero");

        // the `back` slot not ended yet
        if (!empty(window) && window.endTimes[window.end - 1] > block.timestamp) {
            return (window.end - 1, false);
        }

        // add new slot
        uint256 truncated = block.timestamp.div(slotIntervalSecs).mul(slotIntervalSecs);
        window.endTimes[window.end] = truncated.add(slotIntervalSecs);
        window.expirationTimes[window.end] = truncated.add(slotIntervalSecs * numSlots);
        window.end++;

        return (window.end - 1, true);
    }

    function _popFront(TimeoutWindow storage window) private returns (uint256 front) {
        front = window.start;
        delete window.endTimes[front];
        delete window.expirationTimes[front];
        window.start++;
    }

    function popFront(TimeoutWindow storage window) internal returns (uint256, bool) {
        if (empty(window)) {
            return (0, false);
        }

        return (_popFront(window), true);
    }

    function popFrontIfExpired(TimeoutWindow storage window) internal returns (uint256, bool) {
        if (empty(window) || !expired(window, window.start)) {
            return (0, false);
        }

        return popFront(window);
    }

    function tryClear(TimeoutWindow storage window) internal returns (bool) {
        if (!empty(window)) {
            return false;
        }

        if (window.start > 0) {
            window.start = 0;
            window.end = 0;
        }

        return true;
    }

    struct BalanceWindow {
        TimeoutWindow timeouts;
        mapping(uint256 => uint256) slots;  // index => amount
        uint256 expiredBalance;             // expired balance
    }

    function _expire(BalanceWindow storage window) private {
        uint256 expiredBalance = 0;

        while (true) {
            (uint256 front, bool removed) = popFrontIfExpired(window.timeouts);
            if (!removed) {
                break;
            }

            expiredBalance += window.slots[front];
            delete window.slots[front];
        }

        if (expiredBalance > 0) {
            window.expiredBalance += expiredBalance;
        }
    }

    function push(BalanceWindow storage window, uint256 amount, uint256 slotIntervalSecs, uint256 numSlots) internal {
        // gc to avoid long array
        _expire(window);

        (uint256 back, bool added) = pushBackIfEnded(window.timeouts, slotIntervalSecs, numSlots);
        if (added) {
            window.slots[back] = amount;
        } else {
            window.slots[back] += amount;
        }
    }

    function pop(BalanceWindow storage window) internal returns (uint256 expiredBalance) {
        _expire(window);

        expiredBalance = window.expiredBalance;

        if (expiredBalance > 0) {
            window.expiredBalance = 0;
        }
    }

    function pop(BalanceWindow storage window, uint256 amount) internal {
        _expire(window);

        require(amount <= window.expiredBalance, "BalanceWindow: unlocked balance not enough");

        if (amount > 0) {
            window.expiredBalance -= amount;
        }
    }

    function tryClear(BalanceWindow storage window) internal returns (bool) {
        if (window.expiredBalance > 0) {
            return false;
        }

        return tryClear(window.timeouts);
    }

    function clear(BalanceWindow storage window) internal returns (uint256 balance) {
        balance = window.expiredBalance;
        if (balance > 0) {
            window.expiredBalance = 0;
        }

        while (true) {
            (uint256 front, bool removed) = popFront(window.timeouts);
            if (!removed) {
                break;
            }

            balance += window.slots[front];
            delete window.slots[front];
        }

        tryClear(window.timeouts);
    }

    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }

    function balances(BalanceWindow storage window)
        internal view
        returns (uint256 totalBalance, uint256 expiredBalance, LockedBalance[] memory unexpiredBalances)
    {
        totalBalance = window.expiredBalance;
        expiredBalance = window.expiredBalance;

        uint256 index = 0;

        for (uint256 i = window.timeouts.start; i < window.timeouts.end; i++) {
            totalBalance += window.slots[i];

            if (expired(window.timeouts, i)) {
                expiredBalance += window.slots[i];
            } else {
                if (unexpiredBalances.length == 0) {
                    unexpiredBalances = new LockedBalance[](window.timeouts.end - i);
                }

                unexpiredBalances[index] = LockedBalance(window.slots[i], window.timeouts.expirationTimes[i]);
                index++;
            }
        }
    }

}
