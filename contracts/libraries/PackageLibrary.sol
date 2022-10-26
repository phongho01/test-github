// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import { Package } from "./Structs.sol";

library PackageLibrary {
    uint256 public constant MIN_COLLABORATORS = 3;
    uint256 public constant MAX_COLLABORATORS = 10;
    uint256 public constant MAX_OBSERVERS = 10;

    /**
	@dev Throws if there is no package
	 */
    modifier onlyExistingPackage(Package storage package_) {
        require(package_.timeCreated > 0, "no such package");
        _;
    }

    modifier activePackage(Package storage package_) {
        require(package_.isActive, "already canceled!");
        _;
    }

    /**
     * @dev Creates package in project
     * @param package_ reference to Package struct
     * @param budget_ MGP budget
     * @param feeObserversBudget_ Observers fee budget
     * @param bonus_ Bonus budget
     */
    function _createPackage(
        Package storage package_,
        uint256 budget_,
        uint256 feeObserversBudget_,
        uint256 bonus_,
        uint256 maxCollaborators_
    ) internal {
        require(MIN_COLLABORATORS <= maxCollaborators_ && maxCollaborators_ <= MAX_COLLABORATORS, "incorrect max colalborators");
        package_.budget = budget_;
        package_.budgetObservers = feeObserversBudget_;
        package_.bonus = bonus_;
        package_.budgetAllocated = 0;
        package_.maxCollaborators = maxCollaborators_;
        package_.timeCreated = block.timestamp;
        package_.isActive = true;
    }

    function _cancelPackage(Package storage package_) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished == 0, "already finished package");
        package_.timeCanceled = block.timestamp;
        package_.isActive = false;
    }

    /**
     * @dev Adds observers to package
     * @param package_ reference to Package struct
     */
    function _addObserver(Package storage package_) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished == 0, "already finished package");
        require(package_.totalObservers < MAX_OBSERVERS, "Max observers reached");
        package_.totalObservers++;
    }

    /**
     * @dev Removes observers from package
     * @param package_ reference to Package struct
     */
    function _removeObserver(Package storage package_) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished == 0, "already finished package");
        require(package_.totalObservers > 0, "no observers in package");
        package_.totalObservers--;
    }

    /**
     * @dev Reserves collaborators MGP from package budget and increase total number of collaborators,
     * checks if there is budget available and allocates it
     * @param amount_ amount to reserve
     */
    function _reserveCollaboratorsBudget(Package storage package_, uint256 amount_) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished == 0, "already finished package");
        require(package_.budget >= package_.budgetAllocated + amount_, "not enough package budget left");
        require(package_.totalCollaborators < package_.maxCollaborators, "Max collaborators reached");
        package_.budgetAllocated += amount_;
        package_.totalCollaborators++;
    }

    function _revertBudget(Package storage package_) internal view onlyExistingPackage(package_) activePackage(package_) returns (uint256) {
        return (package_.budget - package_.budgetAllocated);
    }

    /**
     * @dev Refund package budget and decreace total collaborators if not approved
     * @param package_ reference to Package struct
     * @param approve_ whether to approve or not collaborator payment
     * @param mgp_ MGP amount
     */
    function _approveCollaborator(
        Package storage package_,
        bool approve_,
        uint256 mgp_
    ) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished == 0, "already finished package");
        if (!approve_) {
            package_.budgetAllocated -= mgp_;
            package_.totalCollaborators--;
        } else {
            package_.approvedCollaborators++;
        }
    }

    function _removeCollaborator(
        Package storage package_,
        uint256 mgp_,
        bool approved_
    ) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished == 0, "already finished package");
        package_.budgetAllocated -= mgp_;
        package_.totalCollaborators--;
        if (approved_) package_.approvedCollaborators--;
    }

    /**
     * @dev Finishes package in project, checks if already finished, records time
     * if budget left and there is no collaborators, bonus is refunded to package budget
     * @param package_ reference to Package struct
     */
    function _finishPackage(Package storage package_) internal onlyExistingPackage(package_) activePackage(package_) returns (uint256 budgetLeft_) {
        require(package_.timeFinished == 0, "already finished package");
        require(package_.disputesCount == 0, "package has unresolved disputes");
        require(package_.totalCollaborators == package_.approvedCollaborators, "unapproved collaborators left");
        budgetLeft_ = package_.budget - package_.budgetAllocated;
        if (package_.totalObservers == 0) budgetLeft_ += package_.budgetObservers;
        if (package_.totalCollaborators == 0) budgetLeft_ += package_.bonus;
        package_.timeFinished = block.timestamp;
        return budgetLeft_;
    }

    /**
     * @dev Sets scores for collaborator bonuses
     * @param package_ reference to Package struct
     * @param collaboratorsGetBonus_ max bonus scores (PPM)
     */
    function _setBonusScores(Package storage package_, uint256 collaboratorsGetBonus_) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.bonus > 0, "zero bonus budget");
        require(package_.timeFinished > 0, "package is not finished");
        package_.collaboratorsGetBonus = collaboratorsGetBonus_;
    }

    /**
     * @dev Gets observer's fee after package is finished
     * @param package_ reference to Package struct
     */
    function _getObserverFee(Package storage package_) internal view onlyExistingPackage(package_) returns (uint256 amount_) {
        require(package_.totalObservers > 0, "no observers in package");
        require(package_.budgetObservers > 0, "zero observer budget");
        uint256 remains = package_.budgetObservers - package_.budgetObserversPaid;
        uint256 portion = package_.budgetObservers / package_.totalObservers;
        amount_ = (remains < 2 * portion) ? remains : portion;
    }

    /**
     * @dev Increases package's observers budget paid
     * @param package_ reference to Package struct
     */
    function _claimObserverFee(Package storage package_) internal returns (uint256 amount_) {
        require(package_.timeFinished > 0, "package is not finished");
        amount_ = _getObserverFee(package_);
        package_.budgetObserversPaid += amount_;
    }

    function _payObserverFee(Package storage package_) internal returns (uint256 amount_) {
        amount_ = _getObserverFee(package_);
        package_.budgetObserversPaid += amount_;
    }

    /**
     * @dev Increases package budget paid
     * @param package_ reference to Package struct
     * @param amount_ MGP amount
     */
    function _claimMgp(Package storage package_, uint256 amount_) internal onlyExistingPackage(package_) {
        require(package_.timeFinished > 0, "package not finished");
        package_.budgetPaid += amount_;
    }

    function _payMgp(Package storage package_, uint256 amount_) internal onlyExistingPackage(package_) {
        package_.budgetPaid += amount_;
    }

    /**
     * @dev Increases package bonus paid
     * @param package_ reference to Package struct
     * @param amount_ Bonus amount
     */
    function _claimBonus(Package storage package_, uint256 amount_) internal onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished > 0, "package not finished");
        require(package_.bonus > 0, "package has no bonus");
        package_.bonusPaid += amount_;
        package_.collaboratorsPaidBonus++;
    }
}
