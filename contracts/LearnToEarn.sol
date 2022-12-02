// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable, SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { ERC165CheckerUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import { ILearnToEarn } from "./interfaces/ILearnToEarn.sol";
import { INFTReward } from "./interfaces/INFTReward.sol";
import { Course, Learner } from "./libraries/Structs.sol";

contract LearnToEarn is ReentrancyGuardUpgradeable, OwnableUpgradeable, ILearnToEarn {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ERC165CheckerUpgradeable for address;

    uint256 public constant REWARD_COMPLETED_DURATION = 60 days;

    // courseId => Course
    mapping(bytes32 => Course) private courseData;

    // courseId => learnerAddress => Learner
    mapping(bytes32 => mapping(address => Learner)) private learnerData;

    /**
     * @notice Throws if amount provided is zero
     */
    modifier nonZero(uint256 amount_) {
        require(amount_ > 0, "Zero amount");
        _;
    }

    /**
     * @notice Throws if called by any account other than the course creator
     */
    modifier onlyCreator(bytes32 _courseId) {
        require(courseData[_courseId].creator == _msgSender(), "caller is not course creator");
        _;
    }

    /* -----------INITILIZER----------- */

    /**
     * @notice Initialize of contract (replace for constructor)
     */
    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /* --------EXTERNAL FUNCTIONS-------- */

    /**
     * @notice Create new course
     * @param _rewardAddress Address of token that reward to student after completing course
     * @param _budget Total tokens/NFTs that reward
     * @param _bonus Bonus when learner completed course
     * @param _timeEndBonus end date will finish bonus, 0 if using duration 60 days
     * @param _isBonusToken Awards is token (true) or NFT (false)
     *
     * emit {CreatedCourse} event
     */
    function createCourse(address _rewardAddress, uint256 _budget, uint256 _bonus, uint256 _timeEndBonus, bool _isBonusToken) external nonZero(_budget) nonZero(_bonus) nonReentrant {
        require(_rewardAddress != address(0), "Invalid reward address");
        require(_budget > _bonus, "Invalid budget");

        bytes32 _courseId = _generateCourseId();
        bool _canMintNFT = false;
        if (!_isBonusToken) {
            // * Using ERC165 to check whether input contract is using INFTReward interface and has `mint` function or not
            _canMintNFT = _rewardAddress.supportsInterface(type(INFTReward).interfaceId);
        }

        courseData[_courseId] = Course({
            creator: _msgSender(),
            rewardAddress: _rewardAddress,
            budget: _budget,
            budgetAvailable: _budget,
            bonus: _bonus,
            totalLearnersClaimedBonus: 0,
            timeCreated: block.timestamp,
            timeEndBonus: _timeEndBonus,
            isBonusToken: _isBonusToken,
            canMintNFT: _canMintNFT
        });

        if (_isBonusToken) {
            IERC20Upgradeable(_rewardAddress).safeTransferFrom(_msgSender(), address(this), _budget);
        }

        emit CreatedCourse(_courseId, _msgSender(), _rewardAddress, _bonus);
    }

    /**
     * @notice Add more budget to course
     * @param _courseId Id of course
     * @param _budget Budget that added to course
     *
     * emit {AddedBudget} events
     */
    function addBudget(bytes32 _courseId, uint256 _budget) external onlyCreator(_courseId) nonZero(_budget) nonReentrant {
        Course storage course = courseData[_courseId];
        course.budget += _budget;
        course.budgetAvailable += _budget;

        if (course.isBonusToken) {
            IERC20Upgradeable(course.rewardAddress).safeTransferFrom(_msgSender(), address(this), _budget);
        }

        emit AddedBudget(_courseId, _budget);
    }

    /**
     * @notice Mark learner completed course and transfer bonus to learner
     * @param _courseId Id of course
     * @param _learner Address of learner
     * @param _timeStarted Time when learner enrolled in course
     * @param _nftIds List Id of nfts that learner will receive if bonus is nfts
     */
    function completeCourse(bytes32 _courseId, address _learner, uint256 _timeStarted, uint256[] memory _nftIds) external onlyCreator(_courseId) {

        Course storage course = courseData[_courseId];
        require(course.timeCreated <= _timeStarted && _timeStarted < block.timestamp, "Invalid time start");

        Learner storage learner = learnerData[_courseId][_learner];
        require(learner.timeCompleted == 0, "already completed");

        learner.timeStarted = _timeStarted;
        learner.timeCompleted = block.timestamp;

        bool canGetBonus = course.budgetAvailable >= course.bonus;
        if(course.timeEndBonus > 0) {
            canGetBonus = canGetBonus && (learner.timeCompleted <= course.timeEndBonus);
        } else {
            canGetBonus = canGetBonus && (learner.timeCompleted <= learner.timeStarted + REWARD_COMPLETED_DURATION);
        }

        if (canGetBonus) {
            course.budgetAvailable -= course.bonus;
            course.totalLearnersClaimedBonus++;

            learner.timeRewarded = block.timestamp;

            if (course.isBonusToken) {
                IERC20Upgradeable(course.rewardAddress).safeTransfer(_learner, course.bonus);
            } else {
                if (course.canMintNFT) {
                    for (uint256 i = 0; i < course.bonus; i++) {
                        learner.nftIds.push(INFTReward(course.rewardAddress).mint(_learner));
                    }
                } else {
                    require(_nftIds.length == course.bonus, "Not enough NFTs");

                    learner.nftIds = _nftIds;
                    for (uint256 i = 0; i < _nftIds.length; i++) {
                        IERC721Upgradeable(course.rewardAddress).safeTransferFrom(_msgSender(), _learner, _nftIds[i]);
                    }
                }
            }
            emit ClaimedReward(_courseId, _learner, course.bonus);
        }

        emit CompletedCourse(_courseId, _learner);
    }

    /* --------VIEW FUNCTIONS-------- */

    /**
     * @notice Get course details
     * @param _courseId Id of course
     * @return Details of course
     */
    function getCourseData(bytes32 _courseId) external view returns (Course memory) {
        return courseData[_courseId];
    }

    /**
     * @notice Get learner course details
     * @param _courseId Id of course
     * @param _learner Address of learner
     * @return Details of learner course
     */
    function getLearnerData(bytes32 _courseId, address _learner) external view returns (Learner memory) {
        return learnerData[_courseId][_learner];
    }

    /* --------PRIVATE FUNCTIONS-------- */

    /**
     * @notice Generates unique id hash based on _msgSender() address and previous block hash.
     * @param _nonce nonce
     * @return Id
     */
    function _generateId(uint256 _nonce) private view returns (bytes32) {
        return keccak256(abi.encodePacked(_msgSender(), blockhash(block.number - 1), _nonce));
    }

    /**
     * @notice Returns a new unique course id.
     * @return _courseId Id of the course.
     */
    function _generateCourseId() private view returns (bytes32 _courseId) {
        _courseId = _generateId(0);
        require(courseData[_courseId].timeCreated == 0, "duplicate course id");
    }
}
