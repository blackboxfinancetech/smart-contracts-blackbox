//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBlackBoxInfo {
    struct UserInfo {
        uint256[] positionIndexesBought;
        uint256 feeTokenRewards;
        uint256 platformTokenRewards;
    }

    function addPositionIndexBought(
        address _userAddress,
        uint256 _positionIndex
    ) external;

    function setBlackBoxAddress(address _blackBoxAddress) external;

    function setFeeTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool);

    function setPlatformTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool);

    function addFeeTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool);

    function addPlatformTokenRewards(address _userAddress, uint256 _amount)
        external
        returns (bool);

    function getFeeTokenRewardsByAddress(address _userAddress)
        external
        view
        returns (uint256);

    function getPlatformTokenRewardsByAddress(address _userAddress)
        external
        view
        returns (uint256);
}
