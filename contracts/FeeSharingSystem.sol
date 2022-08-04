// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IBlackBox.sol";

//FeeToken == RewardToken in this contract
// Shares 18 decimals at contract.
// Rewards 6 decimals at contract.
// AccuFee 6 decimals at contract.
// stakingFeePercentage 3 decimals at initiated.

contract FeeSharingSystem is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 shares; // shares of token staked
        uint256 userRewardPerTokenPaid; //user reward per token paid
        uint256 rewards; //pending rewards
    }

    // Precision factor for calculating rewards and exchange rate
    uint256 public constant PRECISION_FACTOR_BLACK = 10**18;
    uint256 public constant PRECISION_FACTOR_FEE_PERCENTAGE = 10**3;

    IERC20 public immutable rewardToken;
    IERC20 public immutable platformToken;
    IBlackBox public blackBox;

    uint256 public accuStakingFee;

    uint256 public stakingFeePercentage;

    uint256 public lastUpdateAccuFee;

    // Last update block for rewards
    uint256 public lastUpdateBlock;

    // Reward per token stored
    uint256 public rewardPerTokenStored;

    // Total existing shares
    uint256 public totalShares;

    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount, uint256 stakingFee);
    event Harvest(address indexed user, uint256 harvestedAmount);
    event Withdraw(
        address indexed userAddress,
        uint256 amount,
        uint256 harvestedAmount
    );

    constructor(address _platformToken, address _rewardToken) {
        platformToken = IERC20(_platformToken);
        rewardToken = IERC20(_rewardToken);
    }

    function setBlackBoxAddress(address _blackBoxAddress) external onlyOwner {
        blackBox = IBlackBox(_blackBoxAddress);
    }

    function setStakingFeePercentage(uint256 _stakingFeePercentage)
        external
        onlyOwner
    {
        require(
            _stakingFeePercentage < 50 * PRECISION_FACTOR_FEE_PERCENTAGE,
            "feePercentage is out of limit."
        );
        stakingFeePercentage = _stakingFeePercentage;
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(
            _amount >= PRECISION_FACTOR_BLACK,
            "Amount must be >= 1 platformToken"
        );

        // Update reward for user
        _updateReward(msg.sender);

        uint256 stakingFee = (_amount * stakingFeePercentage) /
            (100 * PRECISION_FACTOR_FEE_PERCENTAGE);
        uint256 stakingAmount = _amount - stakingFee;

        // Approve platformToken before deposit

        // Transfer platformToken stakingAmount to this address
        platformToken.safeTransferFrom(
            msg.sender,
            address(this),
            stakingAmount
        );
        //Transfer stakingFee back to blackbox to recirculate
        platformToken.safeTransferFrom(
            msg.sender,
            address(blackBox),
            stakingFee
        );
        accuStakingFee += stakingFee;
        // Adjust internal shares
        userInfo[msg.sender].shares += stakingAmount;
        totalShares += stakingAmount;

        emit Deposit(msg.sender, stakingAmount, stakingFee);
    }

    /**
     * @notice Harvest reward tokens that are pending
     */
    function harvest(address _userAddress) external nonReentrant {
        require(
            msg.sender == address(blackBox),
            "Only Blackbox can call this function"
        );
        // Update reward for user
        _updateReward(_userAddress);

        // Retrieve pending rewards
        uint256 pendingRewards = userInfo[_userAddress].rewards;

        // If pending rewards are null, revert
        require(pendingRewards >= 0, "Harvest: Pending rewards must be >= 0");

        // Adjust user rewards and transfer
        userInfo[_userAddress].rewards = 0;

        // Transfer reward token to sender
        rewardToken.safeTransfer(_userAddress, pendingRewards);

        emit Harvest(_userAddress, pendingRewards);
    }

    /**
     * @notice Withdraw staked tokens (and collect reward tokens)
     * @param shares shares to withdraw
     */
    function withdraw(uint256 shares) external nonReentrant {
        require(
            (shares > 0) && (shares <= userInfo[msg.sender].shares),
            "Withdraw: Shares equal to 0 or larger than user shares"
        );

        _withdraw(shares);
    }

    /**
     * @notice Withdraw all staked tokens (and collect reward tokens)
     */
    function withdrawAll() external nonReentrant {
        _withdraw(userInfo[msg.sender].shares);
    }

    /**
     * @notice Update reward for a user account
     * @param _user address of the user
     */
    function _updateReward(address _user) internal {
        if (block.number > lastUpdateBlock) {
            rewardPerTokenStored = _rewardPerToken();
            lastUpdateBlock = _lastRewardBlock();
        }

        userInfo[_user].rewards = _calculatePendingRewards(_user);
        userInfo[_user].userRewardPerTokenPaid = rewardPerTokenStored; //6 decimals as blackBox fee
    }

    /**
     * @notice Calculate pending rewards for a user
     * @param user address of the user
     */
    function _calculatePendingRewards(address user)
        internal
        view
        returns (uint256)
    {
        return
            ((userInfo[user].shares *
                (rewardPerTokenStored -
                    (userInfo[user].userRewardPerTokenPaid))) /
                PRECISION_FACTOR_BLACK) + userInfo[user].rewards;
    }

    /**
     * @notice Return reward per token
     */
    function _rewardPerToken() internal returns (uint256) {
        if (totalShares == 0) {
            return rewardPerTokenStored;
        }
        uint256 newAccuFee = blackBox.getAccuFee();
        rewardPerTokenStored +=
            (((newAccuFee - lastUpdateAccuFee)) * PRECISION_FACTOR_BLACK) /
            totalShares;
        lastUpdateAccuFee = newAccuFee;
        return rewardPerTokenStored;
    }

    /**
     * @notice Withdraw staked tokens (and collect reward tokens if requested)
     * @param shares shares to withdraw
     */
    function _withdraw(uint256 shares) internal {
        // Update reward for user
        _updateReward(msg.sender);

        userInfo[msg.sender].shares -= shares;
        totalShares -= shares;

        uint256 pendingRewards = userInfo[msg.sender].rewards;
        if (pendingRewards > 0) {
            userInfo[msg.sender].rewards = 0;
            rewardToken.safeTransfer(msg.sender, pendingRewards);
        }

        platformToken.safeTransfer(msg.sender, shares);

        emit Withdraw(msg.sender, shares, pendingRewards);
    }

    function getAddressToUserInfo(address _address)
        external
        view
        returns (UserInfo memory)
    {
        return userInfo[_address];
    }

    /**
     * @notice Return last block where trading rewards were distributed
     */
    function lastRewardBlock() public view returns (uint256) {
        return _lastRewardBlock();
    }

    /**
     * @notice Return last block where rewards must be distributed
     */
    function _lastRewardBlock() internal view returns (uint256) {
        return block.number;
    }

    function getPendingRewards(address user) external view returns (uint256) {
        uint256 rewardPerToken = getRewardPerToken();
        return
            ((userInfo[user].shares *
                (rewardPerToken - (userInfo[user].userRewardPerTokenPaid))) /
                PRECISION_FACTOR_BLACK) + userInfo[user].rewards;
    }

    function getRewardPerToken() public view returns (uint256) {
        if (totalShares == 0) {
            return rewardPerTokenStored;
        }
        uint256 newAccuFee = blackBox.getAccuFee();
        uint256 rewardPerToken = rewardPerTokenStored +
            (((newAccuFee - lastUpdateAccuFee)) * PRECISION_FACTOR_BLACK) /
            totalShares;
        return rewardPerToken;
    }

    function getTotalShares() public view returns (uint256) {
        return totalShares;
    }

    function getStakingFeePercentage() public view returns (uint256) {
        return stakingFeePercentage;
    }
}
