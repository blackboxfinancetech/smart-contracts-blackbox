//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeSharingSystem {
    struct UserInfo {
        uint256 shares; // shares of token staked
        uint256 userRewardPerTokenPaid; //user reward per token paid
        uint256 rewards; //pending rewards
    }

    function deposit(uint256 _amount) external;

    function harvest(address _userAddress) external;

    function withdraw(uint256 shares) external;

    function withdrawAll() external;

    function getAddressToUserInfo(address _address)
        external
        view
        returns (UserInfo memory);
}
