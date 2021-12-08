// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

// This is a rough draft of a Tellor autopay contract. Do not use!

import "usingtellor/contracts/UsingTellor.sol";

interface IERC20 {
  function transfer(address _to, uint256 _amount) external returns(bool);
  function transferFrom(address _from, address _to, uint256 _amount) external returns(bool);
}

contract Autopay is UsingTellor {
    mapping(address => Payer) public payers;
    mapping(bytes32 => bool) public paid; // 
    ITellor public master;

    struct Payer {
        IERC20 token;
        bytes32 queryId;
        uint256 reward;
        uint256 balance;
        uint256 startTime;
        uint256 interval;
        uint256 window;
    }

    constructor(address payable _tellor) UsingTellor(_tellor) {
        master = ITellor(_tellor);
    }

    function claimTip(address _payerAddress, bytes32 _queryId, uint256 _timestamp) public {
        Payer storage _payer = payers[_payerAddress];
        ITellor _oracle = ITellor(master.addresses(keccak256(abi.encode("_ORACLE_CONTRACT"))));
        address _reporter = _oracle.getReporterByTimestamp(_queryId, _timestamp);
        require(_reporter != address(0));
        uint256 _v = (_timestamp - _payer.startTime) / _payer.interval;
        if ((((_timestamp - _payer.startTime) % _payer.interval) * 10000) / 2 > _payer.interval * 10000 / 2) {
            _v+= 1;
        } 
        require(!paid[keccak256(abi.encode(_payerAddress, _v))]);
        uint256 _c = _payer.startTime + _payer.interval * _v;
        (,,uint256 _timestampBefore) = getDataBefore(_queryId, _timestamp);
        require(diff(_timestamp, _c) <= _payer.window && diff(_timestampBefore, _c) > _payer.window); 
        if (_payer.balance >= _payer.reward) {
            IERC20(_payer.token).transfer(_reporter, _payer.reward);
            _payer.balance -= _payer.reward;
        } else {
            IERC20(_payer.token).transfer(_reporter, _payer.balance);
            _payer.balance = 0;
        }
        paid[keccak256(abi.encode(_payerAddress, _v))] = true;
    }

    function setupPayer(address _token, bytes32 _queryId, uint256 _reward, uint256 _startTime, uint256 _interval, uint256 _window) public {
        Payer storage _payer = payers[msg.sender];
        require(_payer.reward == 0);
        require(_reward > 0);
        require(_window * 2 < _interval);
        payers[msg.sender] = Payer({
            token: IERC20(_token),
            queryId: _queryId,
            reward: _reward,
            balance: 0,
            startTime: _startTime,
            interval: _interval,
            window: _window
        });
    }

    function fillPayer(address _payerAddress, uint256 _amount) public {
        Payer storage _payer = payers[_payerAddress];
        require(_payer.reward > 0);
        require(_payer.token.transferFrom(msg.sender, address(this), _amount));
        _payer.balance += _amount;
    }

    function diff(uint256 _a, uint256 _b) public pure returns(uint256) {
        if(_a >= _b) {
            return _a - _b;
        } else {
            return _b - _a;
        }
    }


}