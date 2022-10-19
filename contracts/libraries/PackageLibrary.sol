// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import {Package} from "./Structs.sol";

library PackageLibrary {
    /**
	@dev Throws if there is no package
	 */
    modifier onlyExistingPackage(Package storage package_) {
        require(package_.timeCreated != 0, "no such package");
        _;
    }

    modifier activePackage(Package storage package_) {
        require(package_.isActive == true, "already canceled!");
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
        uint256 bonus_
    ) public {
        package_.budget = budget_;
        package_.budgetAllocated = 0;
        package_.budgetObservers = feeObserversBudget_;
        package_.bonus = bonus_;
        package_.timeCreated = block.timestamp;
        package_.isActive = true;
    }

    function _cancelPackage(Package storage package_)
        public
        onlyExistingPackage(package_)
        activePackage(package_)
    {
        require(package_.timeFinished == 0, "already finished package");
        package_.timeCanceled = block.timestamp;
        package_.isActive = false;
    }

    /**
     * @dev Adds observers to package
     * @param package_ reference to Package struct
     * @param count_ number observer addresses
     */
    function _addObservers(Package storage package_, uint256 count_)
        public
        onlyExistingPackage(package_)
        activePackage(package_)
    {
        require(package_.timeFinished == 0, "already finished package");
        package_.totalObservers += count_;
    }

    /**
     * @dev Reserves collaborators MGP from package budget and increase total number of collaborators,
     * checks if there is budget available and allocates it
     * @param count_ number of collaborators to add
     * @param amount_ amount to reserve
     */
    function _reserveCollaboratorsBudget(
        Package storage package_,
        uint256 count_,
        uint256 amount_
    ) public onlyExistingPackage(package_) activePackage(package_) {
        require(package_.timeFinished == 0, "already finished package");
        require(
            package_.budget - package_.budgetAllocated >= amount_,
            "not enough package budget left"
        );
        package_.budgetAllocated += amount_;
        package_.totalCollaborators += count_;
    }

    function _revertBudget(Package storage package_)
        public
        view
        onlyExistingPackage(package_)
        activePackage(package_)
        returns (uint256)
    {
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
    ) public onlyExistingPackage(package_) activePackage(package_) {
        if (!approve_) {
            package_.budgetAllocated -= mgp_;
            package_.totalCollaborators--;
        } else {
            package_.approvedCollaborators++;
        }
    }

    /**
     * @dev Finishes package in project, checks if already finished, records time
     * if budget left and there is no collaborators, bonus is refunded to package budget
     * @param package_ reference to Package struct
     */
    function _finishPackage(Package storage package_)
        public
        onlyExistingPackage(package_)
        activePackage(package_)
        returns (uint256 budgetLeft_)
    {
        require(package_.timeFinished == 0, "already finished package");
        require(package_.totalCollaborators == package_.approvedCollaborators, "unapproved collaborators left");
        budgetLeft_ = package_.budget - package_.budgetAllocated;
        if (package_.totalObservers == 0)
            budgetLeft_ += package_.budgetObservers;
        if (package_.totalCollaborators == 0) budgetLeft_ += package_.bonus;
        package_.timeFinished = block.timestamp;
        return budgetLeft_;
    }

    /**
     * @dev Sets scores for collaborator bonuses
     * @param package_ reference to Package struct
     * @param totalBonusScores_ total sum of bonus scores
     * @param maxBonusScores_ max bonus scores (PPM)
     */
    function _setBonusScores(
        Package storage package_,
        uint256 totalBonusScores_,
        uint256 maxBonusScores_
    ) public onlyExistingPackage(package_) activePackage(package_) {
        require(package_.bonus != 0, "bonus budget is zero");
        require(package_.timeFinished != 0, "package is not finished");
        require(
            package_.bonusAllocated + totalBonusScores_ <= maxBonusScores_,
            "no more bonus left"
        );
        package_.bonusAllocated += totalBonusScores_;
    }

    /**
     * @dev Sends observer fee after package is finished, increases package budget and observers' budget paid
     * @param package_ reference to Package struct
     * @return amount_ fee amount
     */
    function _getObserverFee(Package storage package_)
        internal
        onlyExistingPackage(package_)
        returns (uint256 amount_)
    {
        require(package_.timeFinished != 0, "package is not finished");
        amount_ = package_.budgetObservers / package_.totalObservers;
        package_.budgetPaid += amount_;
        package_.budgetObserversPaid += amount_;
    }

    /**
     * @dev Increases package budget paid
     * @param package_ reference to Package struct
     * @param amount_ MGP amount
     */
    function _getMgp(Package storage package_, uint256 amount_)
        public
        onlyExistingPackage(package_)
    {
        package_.budgetPaid += amount_;
    }

    /**
     * @dev Increases package bonus paid
     * @param package_ reference to Package struct
     * @param amount_ Bonus amount
     */
    function _paidBonus(Package storage package_, uint256 amount_)
        public
        onlyExistingPackage(package_)
        activePackage(package_)
    {
        require(package_.timeFinished != 0, "package not finished");
        require(package_.bonus != 0, "package has no bonus");
        package_.bonusPaid += amount_;
    }
}
