//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IBlackBox.sol";

contract BlackBoxInfo is Ownable {
    struct UserInfo {
        uint256[] positionIndexBought;
        uint256 feeTokenRewards;
        uint256 platformTokenRewards;
    }

    mapping(address => UserInfo) public addressToUserInfo;

    address public blackBox;
    bool public isSetBlackBox;

    event AddRound(
        uint256 indexed roundIndex,
        uint256 indexed roundId,
        uint256 indexed deadline
    );

    event AddPositionIndexBought(
        address indexed userAddress,
        uint256 indexed roundId
    );

    event AddFeeTokenRewards(address indexed userAddress, uint256 amount);
    event AddPlatformTokenRewards(address indexed userAddress, uint256 amount);

    function addPositionIndexBought(address _userAddress, uint256 _roundId)
        external
    {
        require(msg.sender == blackBox);
        addressToUserInfo[_userAddress].positionIndexBought.push(_roundId);
        emit AddPositionIndexBought(_userAddress, _roundId);
    }

    function setBlackBoxAddress(address _blackBoxAddress) external onlyOwner {
        require(!isSetBlackBox, "Already setBlackBox");
        isSetBlackBox = true;
        blackBox = _blackBoxAddress;
    }

    function setFeeTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool)
    {
        require(msg.sender == blackBox, "Not from blackbox contract");
        addressToUserInfo[_userAddress].feeTokenRewards = _amount;
        return true;
    }

    function setPlatformTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool)
    {
        require(msg.sender == blackBox, "Not from blackbox contract");
        addressToUserInfo[_userAddress].platformTokenRewards = _amount;
        return true;
    }

    function addFeeTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool)
    {
        require(msg.sender == blackBox, "Not from blackbox contract");
        addressToUserInfo[_userAddress].feeTokenRewards += _amount;
        emit AddFeeTokenRewards(_userAddress, _amount);
        return true;
    }

    function addPlatformTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool)
    {
        require(msg.sender == blackBox, "Not from blackbox contract");
        addressToUserInfo[_userAddress].platformTokenRewards += _amount;
        emit AddPlatformTokenRewards(_userAddress, _amount);
        return true;
    }

    function getFeeTokenRewardsByAddress(address _userAddress)
        external
        view
        returns (uint256)
    {
        return addressToUserInfo[_userAddress].feeTokenRewards;
    }

    function getPlatformTokenRewardsByAddress(address _userAddress)
        external
        view
        returns (uint256)
    {
        return addressToUserInfo[_userAddress].platformTokenRewards;
    }

    function getPositionIndexesBoughtByAddress(address _userAddress)
        external
        view
        returns (uint256[] memory)
    {
        return addressToUserInfo[_userAddress].positionIndexBought;
    }
}
