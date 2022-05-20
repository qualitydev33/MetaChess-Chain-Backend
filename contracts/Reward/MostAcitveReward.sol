// SPDX-License-Identifier: UNLICENSED

// contracts/TokenVesting.sol
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MostActiveReward is Context, Ownable {
    using SafeERC20 for IERC20;

    uint256 public weekId=0;
    uint256 public monthId=0;

    uint256 private startWeek;

    IERC20 immutable public token;

    uint256[] public weeklyRewardAmount;
    uint256[] public monthlyRewardAmount;

    struct Winner {
        address user;
        uint256 amount;
    }

    struct User {
        uint256 totalReward;
        uint256 outAmount;
    }
    // weekId => (rating => winner)
    mapping(uint256 => mapping(uint256 => Winner)) weeklyWinners;
    // monthId => (rating => winner)
    mapping(uint256 => mapping(uint256 => Winner)) monthlyWinners;

    mapping(address => User) users;

    modifier isStartedReward() {
        require(weekId > 0, "Ownable: caller is not the owner");
        _;
    }

    function startReward() external onlyOwner {
        weekId = block.timestamp / (3600 * 24 * 7);
        weekId = weekId - 1;
    }

    constructor(address _token) {
        require(_token != address(0x0));
        token = IERC20(_token);
    }

    function addWeeklyWinners(address[] calldata _addresses) external onlyOwner isStartedReward {
        require(_addresses.length <= weeklyRewardAmount.length, "range out");
        uint256 _weekId = block.timestamp / (3600 * 24 * 7);
        require(weekId < _weekId, "already added winners for this week");
        for (uint256 i=0; i < _addresses.length; i++) {
            weeklyWinners[_weekId][i+1] = Winner({
                user: _addresses[i],
                amount: weeklyRewardAmount[i]
            });
            users[_addresses[i]].totalReward += weeklyRewardAmount[i];
        }
        weekId = _weekId;

    }

    function claimWeeklyReward() external isStartedReward {
        uint256 reward = users[msg.sender].totalReward - users[msg.sender].outAmount;
        require(reward > 0, "there is no claimable reward");
        token.safeTransfer(msg.sender, reward);
        users[msg.sender].outAmount += reward;
    }

    function addWeeklyRewardAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "amount is zero ");
        weeklyRewardAmount.push(_amount);
    }

    function setWeeklyRewardAmount(uint256 _id, uint256 _amount) external onlyOwner {
        require(_id < weeklyRewardAmount.length, "range out");
        require(_amount > 0, "amount is zero ");
        weeklyRewardAmount[_id] = _amount;
    }

    function addMonthlyRewardAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "amount is zero ");
        monthlyRewardAmount.push(_amount);
    }

    function setMonthlyRewardAmount(uint256 _id, uint256 _amount) external onlyOwner {
        require(_id < monthlyRewardAmount.length, "range out");
        require(_amount > 0, "amount is zero ");
        monthlyRewardAmount[_id] = _amount;
    }


}