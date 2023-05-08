// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFarm {
    struct PoolInfo {
        address token;
        uint256 allocPoint;
        uint256 lastRewardTime;
        uint256 totalSupply;
        uint256 workingSupply;
        uint256 accRewardPerShare;
    }

    function ppi() external view returns (address);
    function poolLength() external view returns (uint256);
    function poolInfo(uint256 index) external view returns (PoolInfo memory);

    function deposit(uint256 pid, uint256 amount) external returns (uint256 reward);
    function withdraw(uint256 pid, uint256 amount) external returns (uint256 reward);
}
