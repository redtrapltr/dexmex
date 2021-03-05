// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./interfaces/IUniswapV2Pair.sol";
import "./IMasterMex.sol";

contract MasterMex is IMasterMex {
    using SafeMath for uint256;

    event Deposit(address indexed sender, uint256 amount);
    event Receive(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event Reward(address indexed receiver, uint256 amount);
    event Loss(address indexed receiver, uint256 amount);
    event SetGroup(address indexed sender, uint8 indexed voteId);

    constructor() {
        // SWISS-ETH UNI PAIR
        poolInfo.tokenUniPair = 0xE32479d25b6Cb8c02507c3568813E11A37fa32CA;
        getPriceInfo();
    }

    receive() external payable {
        userInfo[msg.sender].pending = userInfo[msg.sender].pending.add(msg.value);

        emit Receive(msg.sender, msg.value);
    }

    function setGroup(uint8 _groupId) external {
        UserInfo storage user = userInfo[msg.sender];
        require(_groupId == UP || _groupId == DOWN, "No group");

        if (user.amount > 0) {
            GroupInfo storage prevGroup = poolInfo.groups[user.groupId];
            prevGroup.deposit = prevGroup.deposit.sub(user.amount);

            GroupInfo storage nextGroup = poolInfo.groups[_groupId];
            nextGroup.deposit = nextGroup.deposit.add(user.amount);
        }
        user.groupId = _groupId;

        emit SetGroup(msg.sender, _groupId);
    }

    function getGroup(uint8 _groupId) public view returns(
        uint256 totalAmt,
        uint256 depositAmt,
        uint256 profitAmt,
        uint256 lossAmt,
        uint256 shareProfitPerETH,
        uint256 extra
    ) {
        require(_groupId == UP || _groupId == DOWN, "No match group");
        totalAmt = poolInfo.groups[_groupId].total;
        depositAmt = poolInfo.groups[_groupId].deposit;
        profitAmt = poolInfo.groups[_groupId].profit;
        lossAmt = poolInfo.groups[_groupId].loss;
        shareProfitPerETH = poolInfo.groups[_groupId].shareProfitPerETH;
        extra = poolInfo.groups[_groupId].extra;
    }

    function deposit() public {
        UserInfo storage user = userInfo[msg.sender];
        GroupInfo storage group = poolInfo.groups[user.groupId];
        uint256 _amount = user.pending;

        user.amount = user.amount.add(_amount);
        user.debt = user.amount.mul(group.shareProfitPerETH).div(10**decimals);
        user.pending = 0;
        group.total = group.total.add(_amount);
        group.deposit = group.deposit.add(_amount);
        emit Deposit(msg.sender, _amount);

        predict();
        if (user.amount > 0) {
            claim();
        }
    }

    function withdraw(uint256 _amount) external {
        UserInfo storage user = userInfo[msg.sender];
        GroupInfo storage group = poolInfo.groups[user.groupId];
        require(getBalance(msg.sender) >= _amount, "Too much requested");

        user.amount = user.amount.sub(_amount);
        user.debt = user.amount.mul(group.shareProfitPerETH).div(10**decimals);
        group.total = group.total.sub(user.amount);
        group.deposit = group.deposit.sub(user.amount);
        
        msg.sender.transfer(_amount);
        emit Withdraw(msg.sender, _amount);

        predict();
        if (user.amount > 0) {
            claim();
        }
    }

    function claim() public {
        UserInfo storage user = userInfo[msg.sender];
        GroupInfo storage group = poolInfo.groups[user.groupId];

        uint256 draftProfit = user.amount.mul(group.shareProfitPerETH).div(10**decimals);
        if (group.hasNegativeProfit) {
            user.amount = user.amount.sub(draftProfit);
            group.deposit = group.deposit.sub(draftProfit);

            group.total = group.total.sub(draftProfit);
            group.loss = group.loss.sub(draftProfit);
            
            emit Loss(msg.sender, draftProfit);
        } else {
            if (draftProfit >= user.debt) {
                draftProfit = draftProfit.sub(user.debt);
                if (draftProfit > 0) {
                    group.total = group.total.sub(draftProfit);
                    group.profit = group.profit.sub(draftProfit);

                    msg.sender.transfer(draftProfit);   // Profit withdrawal
                    emit Reward(msg.sender, draftProfit);
                }
            } else {
                draftProfit = user.debt.sub(draftProfit);   // this is loss
                user.amount = user.amount.sub(draftProfit);
                group.deposit = group.deposit.sub(draftProfit);

                group.total = group.total.sub(draftProfit);
                group.loss = group.loss.sub(draftProfit);

                emit Loss(msg.sender, draftProfit);
            }
        }
    }

    function getBalance(address _user) public view returns(uint256 total) {
        UserInfo storage user = userInfo[_user];
        GroupInfo storage group = poolInfo.groups[user.groupId];

        uint256 draftProfit = user.amount.mul(group.shareProfitPerETH).div(10**decimals);
        if (group.hasNegativeProfit) {
            total = user.amount.sub(draftProfit);
        } else {
            total = user.amount.add(draftProfit).sub(user.debt);
        }
    }

    function getPriceInfo() public returns(uint256 _priceChange, uint256 _precision, uint8 _winGroupId, uint8 _defGroupId) {
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(poolInfo.tokenUniPair).getReserves();
        reserve1 = reserve0.mul(10**decimals).div(reserve1);
        
        if (poolInfo.priceRatio >= reserve1) {
            _priceChange = poolInfo.priceRatio.sub(reserve1);
            _winGroupId = 1;
            _defGroupId = 0;
        } else {
            _priceChange = reserve1.sub(poolInfo.priceRatio);
            _winGroupId = 0;
            _defGroupId = 1;
        }

        if (poolInfo.priceRatio > 0) {
            _priceChange = _priceChange.mul(10**4).div(poolInfo.priceRatio);
        } else {
            _priceChange = _priceChange.mul(10**4).div(10**decimals);
        }
        
        _precision = 2;
        poolInfo.priceRatio = reserve1;

        _priceChange = 10;
        _precision = 0;
        _winGroupId = 0;
        _defGroupId = 1;
    }

    function predict() public returns(bool) {
        if (poolInfo.groups[UP].total < 1) {
            return false;
        }
        if (poolInfo.groups[DOWN].total < 1) {
            return false;
        }

        (uint256 _priceChange, uint256 _precision, uint8 _winGroupId, uint8 _defGroupId) = getPriceInfo();
        
        uint256 bounty = _priceChange.mul(poolInfo.groups[_defGroupId].total).div(10**(_precision.add(2)));

        bounty = _maxLossAmount(_defGroupId, bounty);
        _profit(_winGroupId, bounty);
        _loss(_defGroupId, bounty);
        return true;
    }

    function _loss(uint8 _groupId, uint256 _amount) internal {
        GroupInfo storage group = poolInfo.groups[_groupId];

        group.loss = group.loss.add(_amount);
        group.total = group.total.sub(_amount);
        
        uint256 newLossShare = _amount.mul(10**decimals).div(group.deposit);
        if (group.hasNegativeProfit) {
            group.shareProfitPerETH = group.shareProfitPerETH.add(newLossShare);
        } else {
            if (group.shareProfitPerETH >= newLossShare) {
                group.shareProfitPerETH = group.shareProfitPerETH.sub(newLossShare);
            } else {
                group.shareProfitPerETH = newLossShare.sub(group.shareProfitPerETH);
                group.hasNegativeProfit = true;
            }
        }
    }

    function _profit(uint8 _groupId, uint256 _amount) internal {
        GroupInfo storage group = poolInfo.groups[_groupId];

        group.profit = group.profit.add(_amount);
        group.total = group.total.add(_amount);
        
        uint256 newProfitShare = _amount.mul(10**decimals).div(group.deposit);
        if (group.hasNegativeProfit) {
            if (group.shareProfitPerETH > newProfitShare) {
                group.shareProfitPerETH = group.shareProfitPerETH.sub(newProfitShare);
            } else {
                group.shareProfitPerETH = newProfitShare.sub(group.shareProfitPerETH);
                group.hasNegativeProfit = false;
            }
        } else {
            group.shareProfitPerETH = group.shareProfitPerETH.add(newProfitShare);
        }
    }

    function _maxLossAmount(uint8 _groupId, uint256 _amount) internal view returns(uint256) {
        GroupInfo storage group = poolInfo.groups[_groupId];

        uint256 available = group.deposit.add(group.profit);
        uint256 debt = group.loss.add(_amount);
        if (available < debt) {
            _amount = available.sub(group.loss);
        }

        return _amount;
    }
}