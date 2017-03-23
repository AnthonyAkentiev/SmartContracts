pragma solidity ^0.4.8;

import "./Managed.sol";
import "./TimeHolder.sol";

contract Vote is Managed {

  //defines the poll
  struct Poll {
    address owner;
    bytes32 title;
    bytes32 description;
    uint votelimit;
    uint optionsCount;
    uint deadline;
    bool status;
    uint ipfsHashesCount;
    mapping(address => uint) memberOption;
    mapping(uint => bytes32) ipfsHashes;
    mapping(uint => uint) options;
    mapping(uint => bytes32) optionsId;
  }

    // TimeHolder contract.
   address public timeHolder;

// Polls ids member took part
    mapping(address => uint[]) memberPolls;

  // event tracking new Polls
    event New_Poll(uint _pollId);

  // event tracking of all votes
  event NewVote(uint _choice, uint _pollId);
 
    // Something went wrong.
    event Error(bytes32 message);

  // declare an polls mapping called polls
  mapping(uint => Poll) public polls;
  // Polls counter for mapping 
  uint public pollsCount;

  function init(address _timeHolder, address _userStorage, address _shareable) returns (bool) {
    if (userStorage != 0x0) {
      return false;
    }
    userStorage = _userStorage;
    shareable = _shareable;
    timeHolder = _timeHolder;
    return true;
  }

  //initiator function that stores the necessary poll information
  function NewPoll(bytes32[16] _options, bytes32 _title, bytes32 _description, uint _votelimit, uint _count, uint _deadline) execute(Shareable.Operations.newPoll) returns (uint) {
    polls[pollsCount] = Poll(msg.sender,_title,_description,_votelimit,0,_deadline,true,0);
    for(uint i = 1; i < _count+1; i++) {
      polls[pollsCount].options[i] = 0;
       polls[pollsCount].optionsId[i] = _options[i-1];
       polls[pollsCount].optionsCount++;
    }
    New_Poll(pollsCount);
    return pollsCount++; 
  }

  function getPollTitles() returns (bytes32[] result) {
    result = new bytes32[](pollsCount);
    for(uint i = 0; i<pollsCount; i++)
    {
      result[i] = polls[i].title;
    }
    return (result); 
  }

  function getMemberPolls() returns (uint[]) {  
    return memberPolls[msg.sender];
  }

  function getMemberVotesForPoll(uint _id) returns (uint result) {
    Poll p = polls[_id];
    result = p.memberOption[msg.sender];
    return (result); 
  }

  function getOptionsForPoll(uint _id) returns (bytes32[] result) {
    Poll p = polls[_id];
    result = new bytes32[](p.optionsCount);
    for(uint i = 0; i < p.optionsCount; i++)
    {
      result[i] = p.optionsId[i+1];
    }
    return result;
  }

  function getOptionsVotesForPoll(uint _id) returns (uint[] result) {
    Poll p = polls[_id];
    result = new uint[](p.optionsCount);
    for(uint i = 0; i < p.optionsCount; i++)
    {
      result[i] = p.options[i+1];
    }
    return result;
  }

    function deposit(address _address, uint _amount, uint _total) returns(bool) {
        for(uint i=0;i<memberPolls[_address].length;i++){
           Poll p = polls[memberPolls[_address][i]];
           if(p.status) {
             uint choice = p.memberOption[_address];
             p.options[choice] += _amount;
           }
        }
        return true;
    }

    function withdrawn(address _address, uint _amount, uint _total) returns(bool) {
        for(uint i=0;i<memberPolls[_address].length;i++){
           Poll p = polls[memberPolls[_address][i]];
           if(p.status) {
             uint choice = p.memberOption[_address];
             p.options[choice] -= _amount;
           }
        }
        return true;
    }

    modifier onlyCreator(uint _id) {
        Poll p = polls[_id];
        if(p.owner == msg.sender || this == msg.sender)
        {
          _;
        }
    }

    function addIpfsHashToPoll(uint _id, bytes32 _hash) onlyCreator(_id) returns(bool) {
        Poll p = polls[_id];
        if(p.ipfsHashesCount < 5) {
          p.ipfsHashes[p.ipfsHashesCount++] = _hash;
          return true;
        }
        return false;
    }

    function getIpfsHashesFromPoll(uint _id) returns (bytes32[] result) {
        Poll p = polls[_id];
        result = new bytes32[](p.ipfsHashesCount);
        for(uint i = 0; i < p.ipfsHashesCount; i++)
        {
           result[i] = p.ipfsHashes[i];
        }
        return result;
    }


  //function for user vote. input is a string choice
  function vote(uint _pollId, uint _choice) returns (bool) {
    Poll p = polls[_pollId]; 
    if (_choice == 0 || p.status != true || TimeHolder(timeHolder).shares(msg.sender) == 0 || p.memberOption[msg.sender] != 0) {
      return false;
    }

    p.options[_choice] += TimeHolder(timeHolder).shares(msg.sender);
    p.memberOption[msg.sender] = _choice;
    memberPolls[msg.sender].push(_pollId);
    NewVote(_choice, _pollId);

    // if votelimit reached, end poll
    if (p.votelimit > 0 || p.deadline <= now) {
      if (p.options[_choice] >= p.votelimit) {
        endPoll(_pollId);
      }
    }
    return true;
  }

  //when time or vote limit is reached, set the poll status to false
  function endPoll(uint _pollId) internal returns (bool) {
    Poll p = polls[_pollId];
    p.status = false;
    return true;
  }
}
