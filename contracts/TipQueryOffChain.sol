// SPDX-License-Identifier
pragma solidity 0.8.3;

interface TellorMaster {
    function addresses(bytes32 _selector) external view returns(address);
    function transfer(address _to, uint256 _amount)external returns (bool success);
    function transferFrom(address _from,address _to,uint256 _amount) external returns (bool success);
}

interface Oracle {
    function getReportTimestampByIndex(bytes32 _queryId, uint256 _index)
        external
        view
        returns (uint256);
        
    function getReporterByTimestamp(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (address);
}

contract TipQueryOffChain {
    // (id, tip, nonce)
    mapping(address => uint256) public balances;
    mapping(address => uint256) public actionTimestamps;
    TellorMaster public master;
    uint256 public timelock;
    
    function claimTip(bytes32 _queryId, uint256 _tip, uint256 _nonce, uint8 _v, bytes32 _r, bytes32 _s, bytes32 _hash) external {
        address _signer = ecrecover(_hash, _v, _r, _s);
        require(balances[_signer] >= 0); // If bal < tip, transfer full bal
        require(keccak256(abi.encode(_queryId, _tip, _nonce)) == _hash);
        Oracle _oracle = Oracle(master.addresses(keccak256(abi.encode("_ORACLE_CONTRACT"))));
        uint256 _timestamp = _oracle.getReportTimestampByIndex(_queryId, _nonce);
        require(_timestamp > 0);
        address _reporter = _oracle.getReporterByTimestamp(_queryId, _timestamp);
        if(balances[_signer] >= _tip) {
            master.transfer(_reporter, _tip);
            balances[_signer] -= _tip;
        } else {
            master.transfer(_reporter, balances[_signer]);
            balances[_signer] = 0;
        }
        actionTimestamps[_signer] = block.timestamp;
    }
    
    function deposit(uint256 _amount) external {
        require(master.transferFrom(msg.sender, address(this), _amount));
        balances[msg.sender] += _amount;
        actionTimestamps[msg.sender] = block.timestamp;
    }
    
    function withdraw(uint256 _amount) external {
        require(block.timestamp >= actionTimestamps[msg.sender] + timelock);
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount;
        master.transfer(msg.sender, _amount);
    }
}



// function recoverSignerFromSignature(uint8 v, bytes32 r, bytes32 s, bytes32 hash) external {
//     address signer = ecrecover(hash, v, r, s);
//     require(signer != address(0), "ECDSA: invalid signature");
// }
