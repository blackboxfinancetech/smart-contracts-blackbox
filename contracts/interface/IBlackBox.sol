//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBlackBox {
    enum STATUS {
        OPEN,
        CLOSED
    }
    struct RoundDetail {
        uint256 roundId;
        uint256 deadline;
        uint256 result;
        STATUS roundStatus;
    }
    struct Position {
        address player;
        uint256 roundId;
        uint256 side;
        uint256 amount;
    }

    function addRound(uint256 _roundId, uint256 _deadline) external;

    //Buy BlackBox // USDC has 6 decimals
    function buyBlackBox(
        uint256 _amount,
        uint256 _roundIndex,
        uint256 _side
    ) external;

    function setFeeToken(address _feeTokenAddress) external;

    function setFeePercentage(uint256 _feePercentage) external;

    function setResult(uint256 _roundId, uint256 _result) external;

    function manualUpdateRewardByRoundId(uint256 _roundId) external;

    function setPlatformTokenRewardsPerRound(uint256 _rate) external;

    function withdrawAllRewards() external;

    function withdrawGas() external;

    function depositGas() external payable;

    // Get functions

    function getPositionIndexesByRoundId(uint256 _roundId)
        external
        view
        returns (uint256[] memory);

    function getLeftPositionIndexesByRoundId(uint256 _roundId)
        external
        view
        returns (uint256[] memory);

    function getRightPositionIndexesByRoundId(uint256 _roundId)
        external
        view
        returns (uint256[] memory);

    function getTotalAmountByRoundId(uint256 _roundId)
        external
        view
        returns (uint256);

    function getLeftAmountByRoundId(uint256 _roundId)
        external
        view
        returns (uint256);

    function getRightAmountByRoundId(uint256 _roundId)
        external
        view
        returns (uint256);

    // get notupdatedmatch // return lastUpdateRoundIndex, bool on isThereNotUpdate
    function getNotUpdatedRewardsRoundIndexes()
        external
        view
        returns (uint256[] memory);

    function getActiveRoundIndex()
        external
        view
        returns (uint256[] memory roundIndex);

    function getActiveRoundId()
        external
        view
        returns (uint256[] memory roundIndex);

    function getRoundDetailsByRoundIndex(uint256 _index)
        external
        view
        returns (RoundDetail memory);

    function getPositionsByPositionIndex(uint256 _index)
        external
        view
        returns (Position memory);

    function getFeePercentage() external view returns (uint256);

    function getPlatformTokenRewardsPerRound() external view returns (uint256);

    function getFirstActiveRoundIndex() external view returns (uint256);

    function getAccuFee() external view returns (uint256);
}
