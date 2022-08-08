//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IFeeSharingSystem.sol";
import "./interface/IBlackBoxInfo.sol";

contract BlackBox is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    enum STATUS {
        OPEN,
        CLOSED
    }
    struct Position {
        address player;
        uint256 roundIndex;
        uint256 roundId;
        uint256 side;
        uint256 amount;
    }

    struct RoundDetail {
        uint256 roundId;
        uint256 deadline;
        uint256 result;
        STATUS roundStatus;
    }

    uint256 public constant PRECISION_FACTOR_FEE = 10**6;
    uint256 public constant PRECISION_FACTOR_FEE_PERCENTAGE = 10**3;
    uint256 public constant PRECISION_FACTOR_BLACK = 10**18;

    uint256 public feePercentage;
    uint256 public accuFee;
    uint256 public accuPlatformRewards;
    uint256 public platformTokenRewardsPerRound;
    uint256 public firstActiveRoundIndex;

    IERC20 public feeToken;
    IERC20 public immutable platformToken;
    IFeeSharingSystem public immutable feeSharingSystem;
    IBlackBoxInfo public immutable blackBoxInfo;

    RoundDetail[] public roundDetails;
    Position[] public positions;

    mapping(uint256 => uint256) public roundIndexToRoundId;
    mapping(uint256 => uint256) public positionInRoundToCount;
    mapping(uint256 => uint256) public leftPositionInRoundToCount;
    mapping(uint256 => uint256) public rightPositionInRoundToCount;
    mapping(uint256 => uint256) public roundIndexToInitPositionIndex; //might be change

    event AddRound(
        uint256 indexed roundIndex,
        uint256 indexed roundId,
        uint256 indexed deadline
    );
    event AddPosition(
        address indexed userAddress,
        uint256 indexed positionIndex,
        uint256 indexed roundId,
        uint256 roundIndex,
        uint256 side,
        uint256 amount
    );
    event UpdateRewardPerAddress(
        address indexed userAddress,
        uint256 indexed positionIndex,
        uint256 indexed roundId,
        uint256 side,
        uint256 feeToken,
        uint256 platformToken
    );

    event UpdateReward(
        uint256 indexed roundId,
        uint256 indexed roundIndex,
        uint256 totalFee,
        uint256 platformRewards,
        uint256 result
    );
    event Withdraw(
        address indexed userAddress,
        uint256 feeRewards,
        uint256 platformRewards
    );

    //feePercentage has 3 decimals at initiated
    constructor(
        address _feeTokenAddress,
        address _platformTokenAddress,
        address _feeSharingSystem,
        address _blackBoxInfo,
        uint256 _feePercentage
    ) {
        feeToken = IERC20(_feeTokenAddress);
        platformToken = IERC20(_platformTokenAddress);
        feeSharingSystem = IFeeSharingSystem(_feeSharingSystem);
        blackBoxInfo = IBlackBoxInfo(_blackBoxInfo);
        feePercentage = _feePercentage;
    }

    function _addRound(uint256 _roundId, uint256 _deadline) internal {
        require(
            _deadline >= block.timestamp,
            "Deadline need to be ahead from now"
        );
        RoundDetail memory round = RoundDetail(
            _roundId,
            _deadline,
            0,
            STATUS.OPEN
        );
        roundDetails.push(round);
        uint256 roundIndex = roundDetails.length - 1;
        roundIndexToRoundId[roundIndex] = _roundId;
        emit AddRound(roundIndex, _roundId, _deadline);
    }

    function addRound(uint256 _roundId, uint256 _deadline) public onlyOwner {
        _addRound(_roundId, _deadline);
    }

    //Buy BlackBox // USDC has 6 decimals
    function buyBlackBox(
        uint256 _amount,
        uint256 _roundIndex,
        uint256 _side
    ) public nonReentrant returns (uint256) {
        require(_amount >= 1 * PRECISION_FACTOR_FEE, "Fee must be >= 1 USDC");
        require(
            feeToken.balanceOf(msg.sender) >= _amount,
            "Not enough fee sent"
        );
        require(
            roundDetails[_roundIndex].deadline >= block.timestamp,
            "Round Sale is closed"
        );
        require(_side == 1 || _side == 2, "Not proper side");
        //User need to approve feeToken before transfer
        feeToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 positionsIndex = _addPosition(
            msg.sender,
            _roundIndex,
            _side,
            _amount
        );
        return positionsIndex;
    }

    function _addPosition(
        address _sender,
        uint256 _roundIndex,
        uint256 _side,
        uint256 _totalAmount
    ) internal returns (uint256) {
        uint256 id = roundDetails[_roundIndex].roundId;
        uint256 positionStartIndex = positions.length; //Prob not accurate but the best index we can start loop with
        positions.push(Position(_sender, _roundIndex, id, _side, _totalAmount));
        uint256 positionIndex = positions.length - 1;
        blackBoxInfo.addPositionIndexBought(_sender, positionIndex);
        if (positionInRoundToCount[_roundIndex] == 0) {
            roundIndexToInitPositionIndex[_roundIndex] = positionStartIndex;
        } // adding earliest positionIndex of round
        positionInRoundToCount[_roundIndex]++;
        if (_side == 1) {
            leftPositionInRoundToCount[_roundIndex]++;
        } else if (_side == 2) {
            rightPositionInRoundToCount[_roundIndex]++;
        }
        emit AddPosition(
            _sender,
            positionIndex,
            id,
            _roundIndex,
            _side,
            _totalAmount
        );
        return positionIndex;
    }

    function setFeeToken(address _feeTokenAddress) external onlyOwner {
        feeToken = IERC20(_feeTokenAddress);
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(
            _feePercentage < 50 * PRECISION_FACTOR_FEE_PERCENTAGE,
            "feePercentage is out of limit."
        );
        feePercentage = _feePercentage;
    }

    function setResult(uint256 _roundIndex, uint256 _result) public onlyOwner {
        require(
            _result == 1 || _result == 2 || _result == 3,
            "Incorrect result"
        );

        roundDetails[_roundIndex].result = _result;
    }

    //dont check below here yet
    function _updateRewardByRoundIndex(uint256 _roundIndex) internal {
        console.log("entering updateReward");
        uint256 roundId = roundIndexToRoundId[_roundIndex];
        require(roundDetails[_roundIndex].result != 0, "Result is not set.");
        require(
            roundDetails[_roundIndex].roundStatus == STATUS.OPEN,
            "Status round is closed."
        );
        uint256[] memory totalPositions = getPositionIndexesByRoundIndex(
            _roundIndex
        );
        uint256[] memory leftPositions = getLeftPositionIndexesByRoundIndex(
            _roundIndex
        );
        uint256[] memory rightPositions = getRightPositionIndexesByRoundIndex(
            _roundIndex
        );
        uint256 totalAmount = getTotalAmountByRoundIndex(_roundIndex);
        uint256 leftAmount = getLeftAmountByRoundIndex(_roundIndex);
        uint256 rightAmount = getRightAmountByRoundIndex(_roundIndex);
        uint256 result = roundDetails[_roundIndex].result;
        // tie
        if (result == 3 || leftAmount == 0 || rightAmount == 0) {
            console.log("entering tie");
            roundDetails[_roundIndex].roundStatus = STATUS.CLOSED;
            for (uint256 i = 0; i < totalPositions.length; i++) {
                address player = positions[totalPositions[i]].player;
                uint256 side = positions[totalPositions[i]].side;
                uint256 positionAmount = positions[totalPositions[i]].amount;
                blackBoxInfo.addFeeTokenRewards(player, positionAmount);
                uint256 platformTokenRewardsPerPlayer = ((positionAmount *
                    platformTokenRewardsPerRound) / totalAmount);
                blackBoxInfo.addPlatformTokenRewards(
                    player,
                    platformTokenRewardsPerPlayer
                );
                emit UpdateRewardPerAddress(
                    player,
                    totalPositions[i],
                    roundId,
                    side,
                    positionAmount,
                    platformTokenRewardsPerPlayer
                );
            }
            accuPlatformRewards += platformTokenRewardsPerRound;
            emit UpdateReward(
                roundId,
                _roundIndex,
                0,
                platformTokenRewardsPerRound,
                result
            );
        }
        // Left position win
        else if (result == 1) {
            // sending feeToken to winner
            console.log("entering left win");
            uint256 totalFee = (totalAmount * (feePercentage)) /
                (100 * PRECISION_FACTOR_FEE_PERCENTAGE);
            require(
                feeToken.balanceOf(address(this)) >= (totalFee),
                "Not enough FeeToken to send"
            );
            feeToken.safeTransfer(address(feeSharingSystem), (totalFee));
            accuFee += totalFee;
            roundDetails[_roundIndex].roundStatus = STATUS.CLOSED;
            for (uint256 i = 0; i < leftPositions.length; i++) {
                address player = positions[leftPositions[i]].player;
                uint256 side = positions[leftPositions[i]].side;
                uint256 positionAmount = positions[leftPositions[i]].amount;
                uint256 gainAmount = (((positionAmount * totalAmount) *
                    (100 * PRECISION_FACTOR_FEE_PERCENTAGE - feePercentage)) /
                    (leftAmount * 100 * PRECISION_FACTOR_FEE_PERCENTAGE)) -
                    positionAmount;
                blackBoxInfo.addFeeTokenRewards(
                    player,
                    positionAmount + gainAmount
                );
                emit UpdateRewardPerAddress(
                    player,
                    leftPositions[i],
                    roundId,
                    side,
                    positionAmount + gainAmount,
                    0
                );
            }
            // sending platformToken to loser
            for (uint256 i = 0; i < rightPositions.length; i++) {
                address player = positions[rightPositions[i]].player;
                uint256 side = positions[rightPositions[i]].side;
                uint256 positionAmount = positions[rightPositions[i]].amount;
                uint256 platformTokenRewardsPerPlayer = ((positionAmount *
                    platformTokenRewardsPerRound) / rightAmount);
                blackBoxInfo.addPlatformTokenRewards(
                    player,
                    platformTokenRewardsPerPlayer
                );
                emit UpdateRewardPerAddress(
                    player,
                    rightPositions[i],
                    roundId,
                    side,
                    0,
                    platformTokenRewardsPerPlayer
                );
            }
            accuPlatformRewards += platformTokenRewardsPerRound;
            emit UpdateReward(
                roundId,
                _roundIndex,
                totalFee,
                platformTokenRewardsPerRound,
                result
            );
        }
        // Right position win
        else if (result == 2) {
            console.log("entering right win");
            uint256 totalFee = (totalAmount * (feePercentage)) /
                (100 * PRECISION_FACTOR_FEE_PERCENTAGE);
            require(
                feeToken.balanceOf(address(this)) >= (totalFee),
                "Not enough FeeToken to send"
            );
            feeToken.safeTransfer(address(feeSharingSystem), (totalFee));
            accuFee += totalFee;
            roundDetails[_roundIndex].roundStatus = STATUS.CLOSED;
            for (uint256 i = 0; i < rightPositions.length; i++) {
                address player = positions[rightPositions[i]].player;
                uint256 side = positions[rightPositions[i]].side;
                uint256 positionAmount = positions[rightPositions[i]].amount;
                uint256 gainAmount = (((positionAmount * totalAmount) *
                    (100 * PRECISION_FACTOR_FEE_PERCENTAGE - feePercentage)) /
                    (rightAmount * 100 * PRECISION_FACTOR_FEE_PERCENTAGE)) -
                    positionAmount;
                blackBoxInfo.addFeeTokenRewards(
                    player,
                    positionAmount + gainAmount
                );
                emit UpdateRewardPerAddress(
                    player,
                    rightPositions[i],
                    roundId,
                    side,
                    positionAmount + gainAmount,
                    0
                );
            }
            // sending platformToken to loser
            for (uint256 i = 0; i < leftPositions.length; i++) {
                address player = positions[leftPositions[i]].player;
                uint256 side = positions[leftPositions[i]].side;
                uint256 positionAmount = positions[leftPositions[i]].amount;
                uint256 platformTokenRewardsPerPlayer = ((positionAmount *
                    platformTokenRewardsPerRound) / leftAmount);
                blackBoxInfo.addPlatformTokenRewards(
                    player,
                    platformTokenRewardsPerPlayer
                );
                emit UpdateRewardPerAddress(
                    player,
                    leftPositions[i],
                    roundId,
                    side,
                    0,
                    platformTokenRewardsPerPlayer
                );
            }
            accuPlatformRewards += platformTokenRewardsPerRound;
            emit UpdateReward(
                roundId,
                _roundIndex,
                totalFee,
                platformTokenRewardsPerRound,
                result
            );
        } else {
            console.log("Incorrect result");
        }
    }

    function manualUpdateRewardByRoundIndex(uint256 _roundIndex)
        external
        onlyOwner
    {
        _updateRewardByRoundIndex(_roundIndex);
    }

    function manualUpdateRewards() external onlyOwner {
        _internalUpdateRewards();
    }

    //Looking for every notupdatematches then update every rewards
    function _internalUpdateRewards() internal {
        console.log("enter internal update reward");
        uint256[]
            memory notUpdateRoundIndexes = getNotUpdatedRewardsRoundIndexes();
        for (uint256 i = 0; i < notUpdateRoundIndexes.length; i++) {
            uint256 currentIndex = notUpdateRoundIndexes[i];
            _updateRewardByRoundIndex(currentIndex);
        }
        _updateActiveFirstRoundIndex();
    }

    function _updateActiveFirstRoundIndex() internal {
        for (uint256 i = firstActiveRoundIndex; i < roundDetails.length; i++) {
            if (roundDetails[i].roundStatus == STATUS.OPEN) {
                firstActiveRoundIndex = i;
                break;
            }
        }
    }

    function setPlatformTokenRewardsPerRound(uint256 _rate) public onlyOwner {
        require(
            _rate >= 0 || _rate <= 1000000 * PRECISION_FACTOR_BLACK,
            "rate is out of limit"
        );
        platformTokenRewardsPerRound = _rate;
    }

    function simpleWithdraw() external nonReentrant {
        uint256 newFeeRewards = blackBoxInfo.getFeeTokenRewardsByAddress(
            msg.sender
        );
        uint256 newPlatformRewards = blackBoxInfo
            .getPlatformTokenRewardsByAddress(msg.sender);
        bool isSetFeeSuccess = blackBoxInfo.setFeeTokenRewards(msg.sender, 0);
        bool isSetPlatformSuccess = blackBoxInfo.setPlatformTokenRewards(
            msg.sender,
            0
        );
        require(isSetFeeSuccess && isSetPlatformSuccess, "Failed set rewards");
        feeToken.safeTransfer(msg.sender, newFeeRewards);
        platformToken.safeTransfer(msg.sender, newPlatformRewards);
        //Withdraw stakingRewards by calling FeeSharingSystem
        feeSharingSystem.harvest(msg.sender);
        emit Withdraw(msg.sender, newFeeRewards, newPlatformRewards);
    }

    function withdrawWithUpdates() external nonReentrant {
        //Update reward before withdraw
        _internalUpdateRewards();
        uint256 newFeeRewards = blackBoxInfo.getFeeTokenRewardsByAddress(
            msg.sender
        );
        uint256 newPlatformRewards = blackBoxInfo
            .getPlatformTokenRewardsByAddress(msg.sender);
        bool isSetFeeSuccess = blackBoxInfo.setFeeTokenRewards(msg.sender, 0);
        bool isSetPlatformSuccess = blackBoxInfo.setPlatformTokenRewards(
            msg.sender,
            0
        );
        require(isSetFeeSuccess && isSetPlatformSuccess, "Failed set rewards");
        feeToken.safeTransfer(msg.sender, newFeeRewards);
        platformToken.safeTransfer(msg.sender, newPlatformRewards);
        //Withdraw stakingRewards by calling FeeSharingSystem
        feeSharingSystem.harvest(msg.sender);
        emit Withdraw(msg.sender, newFeeRewards, newPlatformRewards);
    }

    function withdrawGas() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function depositGas() external payable {
        console.log("deposit to contract");
    }

    // Get functions

    function getPositionIndexesByRoundIndex(uint256 _roundIndex)
        public
        view
        returns (uint256[] memory)
    {
        uint256 positionByRoundLength = positionInRoundToCount[_roundIndex];
        uint256 initPositionIndex = roundIndexToInitPositionIndex[_roundIndex];
        uint256[] memory selectedPositions = new uint256[](
            positionByRoundLength
        );
        uint256 counter = 0;
        for (uint256 i = initPositionIndex; i < positions.length; i++) {
            if (positions[i].roundIndex == _roundIndex) {
                selectedPositions[counter] = i;
                counter++;
            }
        }
        return selectedPositions;
    }

    function getLeftPositionIndexesByRoundIndex(uint256 _roundIndex)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory selectedPositions = getPositionIndexesByRoundIndex(
            _roundIndex
        );
        uint256[] memory leftPositions = new uint256[](
            leftPositionInRoundToCount[_roundIndex]
        );
        uint256 counter = 0;
        uint256 result = 1;
        for (uint256 i = 0; i < selectedPositions.length; i++) {
            if (positions[selectedPositions[i]].side == result) {
                leftPositions[counter] = selectedPositions[i];
                counter++;
            }
        }
        return leftPositions;
    }

    function getRightPositionIndexesByRoundIndex(uint256 _roundIndex)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory selectedPositions = getPositionIndexesByRoundIndex(
            _roundIndex
        );
        uint256[] memory rightPositions = new uint256[](
            rightPositionInRoundToCount[_roundIndex]
        );
        uint256 counter = 0;
        uint256 result = 2;
        for (uint256 i = 0; i < selectedPositions.length; i++) {
            if (positions[selectedPositions[i]].side == result) {
                rightPositions[counter] = selectedPositions[i];
                counter++;
            }
        }
        return rightPositions;
    }

    function getTotalAmountByRoundIndex(uint256 _roundIndex)
        public
        view
        returns (uint256)
    {
        uint256 totalAmount = 0;
        uint256[] memory selectedPositions = getPositionIndexesByRoundIndex(
            _roundIndex
        );
        for (uint256 i = 0; i < selectedPositions.length; i++) {
            totalAmount += positions[selectedPositions[i]].amount;
        }
        return totalAmount;
    }

    function getLeftAmountByRoundIndex(uint256 _roundIndex)
        public
        view
        returns (uint256)
    {
        uint256 leftAmount = 0;
        uint256[] memory selectedPositions = getLeftPositionIndexesByRoundIndex(
            _roundIndex
        );
        for (uint256 i = 0; i < selectedPositions.length; i++) {
            leftAmount += positions[selectedPositions[i]].amount;
        }
        return leftAmount;
    }

    function getRightAmountByRoundIndex(uint256 _roundIndex)
        public
        view
        returns (uint256)
    {
        uint256 rightAmount = 0;
        uint256[]
            memory selectedPositions = getRightPositionIndexesByRoundIndex(
                _roundIndex
            );
        for (uint256 i = 0; i < selectedPositions.length; i++) {
            rightAmount += positions[selectedPositions[i]].amount;
        }
        return rightAmount;
    }

    // get notupdatedmatch // return lastUpdateRoundIndex, bool on isThereNotUpdate
    function getNotUpdatedRewardsRoundIndexes()
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory activeRoundIndexes = getActiveRoundIndexes();
        uint256 lengthCounter;
        for (uint256 i = 0; i < activeRoundIndexes.length; i++) {
            if (
                roundDetails[activeRoundIndexes[i]].roundStatus ==
                STATUS.OPEN &&
                roundDetails[activeRoundIndexes[i]].result != 0
            ) {
                lengthCounter++;
            }
        }
        uint256[] memory notUpdatedRoundIndexes = new uint256[](lengthCounter);
        uint256 counter;
        for (uint256 i = 0; i < activeRoundIndexes.length; i++) {
            if (
                roundDetails[activeRoundIndexes[i]].roundStatus ==
                STATUS.OPEN &&
                roundDetails[activeRoundIndexes[i]].result != 0
            ) {
                notUpdatedRoundIndexes[counter] = activeRoundIndexes[i];
                counter++;
            }
        }
        return notUpdatedRoundIndexes;
    }

    function getActiveRoundIndexes() public view returns (uint256[] memory) {
        uint256 lengthCounter = 0;
        for (uint256 i = firstActiveRoundIndex; i < roundDetails.length; i++) {
            if (roundDetails[i].roundStatus == STATUS.OPEN) {
                lengthCounter++;
            }
        }
        uint256[] memory activeRounds = new uint256[](lengthCounter);
        uint256 counter = 0;
        for (uint256 i = firstActiveRoundIndex; i < roundDetails.length; i++) {
            if (roundDetails[i].roundStatus == STATUS.OPEN) {
                activeRounds[counter] = i;
                counter++;
            }
        }
        return activeRounds;
    }

    function getRoundDetailsByRoundIndex(uint256 _index)
        public
        view
        returns (RoundDetail memory)
    {
        return roundDetails[_index];
    }

    function getPositionsByPositionIndex(uint256 _index)
        public
        view
        returns (Position memory)
    {
        return positions[_index];
    }

    function getFeePercentage() public view returns (uint256) {
        return feePercentage;
    }

    function getPlatformTokenRewardsPerRound() public view returns (uint256) {
        return platformTokenRewardsPerRound;
    }

    function getFirstActiveRoundIndex() public view returns (uint256) {
        return firstActiveRoundIndex;
    }

    function getAccuFee() public view returns (uint256) {
        return accuFee;
    }
}
