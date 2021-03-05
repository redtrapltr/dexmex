// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract IMasterMex {
    struct UserInfo {
        uint256 amount;
        uint256 pending;
        uint256 debt;
        uint8 groupId;
    }

    struct GroupInfo {
        uint256 total;
        uint256 deposit;
        uint256 profit;
        uint256 loss;
        uint256 shareProfitPerETH;
        uint256 extra;
        bool hasNegativeProfit;
    }

    struct PoolInfo {
        address tokenUniPair;
        uint priceRatio;
        uint8 minLeverage;
        uint8 maxLeverage;
        mapping(uint8 => GroupInfo) groups;
    }

    uint8 constant UP = 1;
    uint8 constant DOWN = 0;
    uint256 public decimals = 18;

    PoolInfo public poolInfo;
    mapping(address => UserInfo) public userInfo;
}