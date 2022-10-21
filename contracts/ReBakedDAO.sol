// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import { IReBakedDAO } from "./interfaces/IReBakedDAO.sol";
import { ITokenFactory } from "./interfaces/ITokenFactory.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Project, ProjectLibrary } from "./libraries/ProjectLibrary.sol";
import { Package, PackageLibrary } from "./libraries/PackageLibrary.sol";
import { Collaborator, CollaboratorLibrary } from "./libraries/CollaboratorLibrary.sol";
import { Observer, ObserverLibrary } from "./libraries/ObserverLibrary.sol";

contract ReBakedDAO is IReBakedDAO, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ProjectLibrary for Project;
    using PackageLibrary for Package;
    using CollaboratorLibrary for Collaborator;
    using ObserverLibrary for Observer;

    // Rebaked DAO wallet
    address public treasury;
    // Percent Precision PPM (parts per million)
    uint256 public constant PCT_PRECISION = 1e6;
    // Fee for DAO for new projects
    uint256 public feeDao;
    // Fee for Observers for new projects
    uint256 public feeObservers;
    // Token Factory contract address
    address public tokenFactory;

    mapping(bytes32 => Project) private projectData;

    mapping(bytes32 => mapping(bytes32 => Package)) private packageData;

    // address of approved collaborator with perticular package
    mapping(bytes32 => mapping(bytes32 => mapping(address => bool))) private approvedUser;

    // projectId => packageId => address collaborator
    mapping(bytes32 => mapping(bytes32 => mapping(address => Collaborator))) private collaboratorData;

    // projectId => packageId => address observer
    mapping(bytes32 => mapping(bytes32 => mapping(address => Observer))) private observerData;

    constructor(
        address treasury_,
        uint256 feeDao_,
        uint256 feeObservers_,
        address tokenFactory_
    ) {
        treasury = treasury_;
        changeFees(feeDao_, feeObservers_);
        tokenFactory = tokenFactory_;
    }

    /**
     * @dev Throws if amount provided is zero
     */
    modifier nonZero(uint256 amount_) {
        require(amount_ != 0, "Zero amount");
        _;
    }

    /**
     * @dev Throws if amount provided bytes32 array length is zero
     */
    modifier nonEmptyBytesArray(bytes32[] memory array_) {
        require(array_.length != 0, "Empty array");
        _;
    }

    /**
     * @dev Throws if amount provided uint256 array length is zero
     */
    modifier nonEmptyUintArray(uint256[] memory array_) {
        require(array_.length != 0, "Empty array");
        _;
    }

    /**
     * @dev Throws if called by any account other than the project initiator
     */
    modifier onlyInitiator(bytes32 projectId_) {
        require(projectData[projectId_].initiator == msg.sender, "caller is not project initiator");
        _;
    }

    /***************************************
					PRIVATE
	****************************************/
    /**
     * @dev Generates unique id hash based on msg.sender address and previous block hash.
     * @param nonce_ nonce
     * @return Id
     */
    function _generateId(uint256 nonce_) private view returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender, blockhash(block.number - 1), nonce_));
    }

    /**
     * @dev Returns a new unique project id.
     * @return projectId_ Id of the project.
     */
    function _generateProjectId() private view returns (bytes32 projectId_) {
        projectId_ = _generateId(0);
        require(projectData[projectId_].timeCreated == 0, "duplicate project id");
    }

    /**
     * @dev Returns a new unique package id.
     * @param projectId_ Id of the project
     * @param nonce_ nonce
     * @return packageId_ Id of the package
     */
    function _generatePackageId(bytes32 projectId_, uint256 nonce_) private view returns (bytes32 packageId_) {
        packageId_ = _generateId(nonce_);
        require(packageData[projectId_][packageId_].timeCreated == 0, "duplicate package id");
    }

    /**
     * @dev Starts project
     * @param projectId_ Id of the project
     */
    function _startProject(bytes32 projectId_) private {
        uint256 _paidAmount = projectData[projectId_].budget;
        projectData[projectId_]._startProject(tokenFactory);
        emit StartedProject(projectId_, _paidAmount);
    }

    /**
     * @dev Approves collaborator's MPG (or deletes collaborator should be called by admin)
     * @param projectId_ Id of the project
     * @param packageId_ Id of the package
     * @param collaborator_ collaborator's address
     * @param approve_ - bool whether to approve or not collaborator payment
     */
    function _approveCollaborator(
        bytes32 projectId_,
        bytes32 packageId_,
        address collaborator_,
        bool approve_
    ) private {
        collaboratorData[projectId_][packageId_][collaborator_]._approveCollaborator(approve_);
        if (!approve_) delete collaboratorData[projectId_][packageId_][collaborator_];

        uint256 mgp_ = collaboratorData[projectId_][packageId_][collaborator_].mgp;
        packageData[projectId_][packageId_]._approveCollaborator(approve_, mgp_);
        if (approve_) approvedUser[projectId_][packageId_][collaborator_] = true;
    }

    function _addObserver(
        bytes32 projectId_,
        bytes32 packageId_,
        address observer_
    ) private {
        require(observer_ != address(0), "observer's address is zero");
        Observer storage _observer = observerData[projectId_][packageId_][observer_];
        _observer._addObserver();
    }

    function _removeCollaboratorByInitiator(
        bytes32 projectId_,
        bytes32 packageId_,
        address collaborator_
    ) private {
        require(collaborator_ != address(0), "collaborator's address is zero");
        collaboratorData[projectId_][packageId_][collaborator_]._removeCollaboratorByInitiator();
    }

    /***************************************
					ADMIN
	****************************************/

    function updateTreasury(address treasury_) public onlyOwner {
        treasury = treasury_;
    }

    /**
     * @dev Sets new fees
     * @param feeDao_ DAO fee in ppm
     * @param feeObservers_ Observers fee in ppm
     */
    function changeFees(uint256 feeDao_, uint256 feeObservers_) public onlyOwner {
        feeDao = feeDao_;
        feeObservers = feeObservers_;
        emit ChangedFees(feeDao_, feeObservers_);
    }

    function _approveProject(bytes32 projectId_) private {
        projectData[projectId_]._approveProject();
        emit ApprovedProject(projectId_);
    }

    /**
     * @dev Approves project
     * @param projectId_ Id of the project
     */
    function approveProject(bytes32 projectId_) external onlyOwner {
        _approveProject(projectId_);
    }

    /**
     * @dev Sets scores for collaborator bonuses
     * @param projectId_ Id of the project
     * @param packageId_ Id of the package
     * @param collaborators_ array of collaborators' addresses
     * @param scores_ array of collaboratos' scores in PPM
     */
    function setBonusScores(
        bytes32 projectId_,
        bytes32 packageId_,
        address[] memory collaborators_,
        uint256[] memory scores_
    ) external nonEmptyUintArray(scores_) onlyOwner {
        require(collaborators_.length == scores_.length, "arrays length mismatch");
        uint256 _totalBonusScores;
        for (uint256 i = 0; i < collaborators_.length; i++) {
            if (collaboratorData[projectId_][packageId_][collaborators_[i]].bonusScore == 0) {
                // _setBonusScore(projectId_, packageId_, collaborators_[i], scores_[i]);
                collaboratorData[projectId_][packageId_][collaborators_[i]]._setBonusScore(scores_[i]);
                _totalBonusScores += scores_[i];
            }
        }
        // _setBonusScores(projectId_, packageId_, _totalBonusScores, PCT_PRECISION);
        packageData[projectId_][packageId_]._setBonusScores(_totalBonusScores, PCT_PRECISION);
        emit SetBonusScores(projectId_, packageId_, collaborators_, scores_);
    }

    /**
     * @dev Dispute Raise on collaborator, Set isDisputed flag, Checks that user is either collaborator or initiator
     * @param _projectId Id of the project
     * @param _packageId Id of the package
     * @param _collaborator collaborator's address
     */

    function raiseDispute(
        bytes32 _projectId,
        bytes32 _packageId,
        address _collaborator
    ) external {
        require(
            msg.sender == projectData[_projectId].initiator ||
            approvedUser[_projectId][_packageId][msg.sender],
            "Caller not authorized"
        );
        Collaborator storage collaborator = collaboratorData[_projectId][_packageId][_collaborator];
        collaborator._raiseDispute();
    }

    /**
     * @dev Approve Payment of disputed collaborator, Set isDisputed flag
     * @param _projectId Id of the project
     * @param _packageId Id of the package
     * @param _collaborator collaborator's address
     */

    function approvePayment(
        bytes32 _projectId,
        bytes32 _packageId,
        address _collaborator
    ) external onlyOwner {
        Collaborator storage collaborator = collaboratorData[_projectId][_packageId][_collaborator];
        collaborator._resolveDispute(true);
    }

    /**
     * @dev Get payment details of collaborator
     * @param _projectId Id of the project
     * @param _packageId Id of the package
     * @param _collaborator collaborator's address
     * @return collaborator's mgp and bonus
     */

    function getRejectedPayment(
        bytes32 _projectId,
        bytes32 _packageId,
        address _collaborator
    ) external view onlyOwner returns (uint256, uint256) {
        Collaborator memory collaborator = collaboratorData[_projectId][_packageId][_collaborator];
        return (collaborator.mgp, collaborator.bonusScore);
    }

    /**
     * @dev Reject payment of collaborator
     * @param _projectId Id of the project
     * @param _packageId Id of the package
     * @param _collaborator collaborator's address
     */

    function rejectPayment(
        bytes32 _projectId,
        bytes32 _packageId,
        address _collaborator
    ) external onlyOwner {
        Collaborator storage collaborator = collaboratorData[_projectId][_packageId][_collaborator];
        uint256 _feesToBeRevert = collaborator.mgp + collaborator.bonusScore;
        collaborator._resolveDispute(false);
        address _token = projectData[_projectId].token;
        address _initiator = projectData[_projectId].initiator;
        IERC20(_token).safeTransfer(_initiator, _feesToBeRevert);
    }

    /***************************************
			PROJECT INITIATOR ACTIONS
	****************************************/

    /**
     * @dev Creates project proposal
     * @param token_ project token address, zero addres if project has not token yet
     * (IOUToken will be deployed on project approval)
     * @param budget_ total budget (has to be approved on token contract if project has its own token)
     * @return projectId_ Id of the project proposal created
     */
    function createProject(address token_, uint256 budget_) external nonZero(budget_) returns (bytes32 projectId_) {
        projectId_ = _generateProjectId();
        projectData[projectId_]._createProject(token_, budget_);
        emit CreatedProject(projectId_, msg.sender, token_, budget_);
        if (token_ != address(0)) {
            _approveProject(projectId_);
            _startProject(projectId_);
        }
    }

    /**
     * @dev Starts project
     * @param projectId_ Id of the project
     */
    function startProject(bytes32 projectId_) external onlyInitiator(projectId_) {
        _startProject(projectId_);
    }

    /**
     * @dev Creates package in project
     * @param projectId_ Id of the project
     * @param budget_ MGP budget
     * @param bonus_ Bonus budget
     * @return packageId_ Id of the package created
     */
    function createPackage(
        bytes32 projectId_,
        uint256 budget_,
        uint256 bonus_,
        uint256 observerBudget_
    ) external onlyInitiator(projectId_) nonZero(budget_) returns (bytes32 packageId_) {
        packageId_ = _generatePackageId(projectId_, 0);
        packageData[projectId_][packageId_]._createPackage(budget_, observerBudget_, bonus_);
        Project storage project = projectData[projectId_];
        address _token = project.token;
        uint256 total = budget_ + bonus_ + observerBudget_;
        project._reservePackagesBudget(total, 1);
        if (project.isOwnToken) {
            IERC20(_token).safeTransferFrom(msg.sender, treasury, (total * 5) / 100);
        }
        emit CreatedPackage(projectId_, packageId_, budget_, bonus_);
    }

    /// collab and observer withdraw
    function cancelPackage(
        bytes32 projectId_,
        bytes32 packageId_,
        address[] memory collaborator_,
        address[] memory observer_
    ) external onlyInitiator(projectId_) {
        for (uint256 i = 0; i < collaborator_.length; i++) {
            payMgp(projectId_, packageId_, collaborator_[i]);
        }
        for (uint256 i = 0; i < observer_.length; i++) {
            payObserverFee(projectId_, packageId_, observer_[i]);
        }
        uint256 budgetToBeReverted_;
        budgetToBeReverted_ = packageData[projectId_][packageId_].budget - packageData[projectId_][packageId_].budgetPaid;
        projectData[projectId_]._revertPackageBudget(budgetToBeReverted_);
        packageData[projectId_][packageId_]._cancelPackage();
    }

    /**
     * @dev Adds collaborator to package
     * @param projectId_ Id of the project
     * @param packageId_ Id of the package
     * @param collaborator_ collaborators' addresses
     * @param mgp_ MGP amount
     */
    function addCollaborator(
        bytes32 projectId_,
        bytes32 packageId_,
        address collaborator_,
        uint256 mgp_
    ) external onlyInitiator(projectId_) nonZero(mgp_) {
        require(collaborator_ != address(0), "collaborator's address is zero");
        collaboratorData[projectId_][packageId_][collaborator_]._addCollaborator(mgp_);
        packageData[projectId_][packageId_]._reserveCollaboratorsBudget(1, mgp_);
        emit AddedCollaborator(projectId_, packageId_, collaborator_, mgp_);
    }

    /**
     * @dev Approves collaborator's MGP or deletes collaborator (should be called by admin)
     * @param projectId_ Id of the project
     * @param packageId_ Id of the package
     * @param collaborator_ collaborator's address
     * @param approve_ - bool whether to approve or not collaborator payment
     */
    function approveCollaborator(
        bytes32 projectId_,
        bytes32 packageId_,
        address collaborator_,
        bool approve_
    ) external onlyInitiator(projectId_) {
        _approveCollaborator(projectId_, packageId_, collaborator_, approve_);
        emit ApprovedCollaborator(projectId_, packageId_, collaborator_, approve_);
    }

    function removeCollaborator(
        bytes32 projectId_,
        bytes32 packageId_,
        address collaborator_,
        bool packageStatus
    ) external onlyInitiator(projectId_) {
        require(collaborator_ != address(0), "collaborator's address is zero");
        require(collaboratorData[projectId_][packageId_][collaborator_].timeBonusPaid > 0, "Bonus Already Paid");

        if (packageStatus == true) { //  inprogress/deliver/
            payMgp(projectId_, packageId_, collaborator_);
            _removeCollaboratorByInitiator(projectId_, packageId_, collaborator_);
        } else { // open
            // _selfWithdraw(projectId_, packageId_, collaborator_);
            packageData[projectId_][packageId_].budgetAllocated -= collaboratorData[projectId_][packageId_][collaborator_].mgp;
            packageData[projectId_][packageId_].totalCollaborators -= 1;
            packageData[projectId_][packageId_].approvedCollaborators -= 1;
            collaboratorData[projectId_][packageId_][collaborator_]._selfWithdraw();
        }
        packageData[projectId_][packageId_].budgetAllocated -= collaboratorData[projectId_][packageId_][collaborator_].bonusScore;
    }

    /**
     * @dev Adds observer to packages
     * @param projectId_ Id of the project
     * @param packageIds_ Id of the package
     * @param observer_ observer address
     */
    function addObserver(
        bytes32 projectId_,
        bytes32[] memory packageIds_,
        address observer_
    ) external onlyInitiator(projectId_) {
        for (uint256 i = 0; i < packageIds_.length; i++) {
            _addObserver(projectId_, packageIds_[i], observer_);
            packageData[projectId_][packageIds_[i]]._addObservers(1);
        }
        emit AddedObserver(projectId_, packageIds_, observer_);
    }

    /**
     * @dev Removes observer from packages
     * @param projectId_ Id of the project
     * @param packageIds_ packages' ids
     * @param observer_ observer address
     */
    function removeObserver(
        bytes32 projectId_,
        bytes32[] memory packageIds_,
        address observer_
    ) external onlyInitiator(projectId_) {
        for (uint256 i = 0; i < packageIds_.length; i++) {
            Package storage package = packageData[projectId_][packageIds_[i]];
            package._removeObservers(1);
            Observer storage observer = observerData[projectId_][packageIds_[i]][observer_];
            observer._removeObserver();
        }
    }

    function payMgp(
        bytes32 projectId_,
        bytes32 packageId_,
        address collaborator_
    ) public onlyInitiator(projectId_) {
        require(approvedUser[projectId_][packageId_][collaborator_], "No such collaborator");
        Collaborator storage collaborator = collaboratorData[projectId_][packageId_][collaborator_];
        uint256 amount_ = collaborator._getMgp();
        packageData[projectId_][packageId_]._getMgp(amount_);
        projectData[projectId_]._pay(collaborator_, amount_);
    }

    function payObserverFee(
        bytes32 projectId_,
        bytes32 packageId_,
        address observer_
    ) public nonReentrant onlyInitiator(projectId_) {
        Observer storage observer = observerData[projectId_][packageId_][observer_];
        observer._claimObserverFee();
        Package storage package = packageData[projectId_][packageId_];
        uint256 amount_ = package._getObserverFee();
        projectData[projectId_]._pay(observer_, amount_);
        emit PaidObserverFee(projectId_, packageId_, observer_, amount_);
    }

    /**
     * @dev Finishes package in project
     * @param projectId_ Id of the project
     */
    function finishPackage(bytes32 projectId_, bytes32 packageId_) external onlyInitiator(projectId_) returns (uint256 budgetLeft_) {
        budgetLeft_ = packageData[projectId_][packageId_]._finishPackage();
        projectData[projectId_]._finishPackage(budgetLeft_);
        emit FinishedPackage(projectId_, packageId_, budgetLeft_);
    }

    /**
     * @dev Finishes project
     * @param projectId_ Id of the project
     */
    function finishProject(bytes32 projectId_) external onlyInitiator(projectId_) {
        projectData[projectId_]._finishProject(treasury);
        emit FinishedProject(projectId_);
    }

    /***************************************
			COLLABORATOR ACTIONS
	****************************************/
    /**
     * @dev Sends approved MGP to collaborator, should be called from collaborator's address
     * @param projectId_ Id of the project
     * @param packageId_ Id of the package
     */
    function getMgp(bytes32 projectId_, bytes32 packageId_) public nonReentrant returns (uint256 amount_) {
        address collaborator_ = msg.sender;
        require(approvedUser[projectId_][packageId_][collaborator_], "Only Collaborator Can Call!");
        Collaborator storage collaborator = collaboratorData[projectId_][packageId_][collaborator_];
        amount_ = collaborator._getMgp();
        packageData[projectId_][packageId_]._getMgp(amount_);
        projectData[projectId_]._pay(collaborator_, amount_);
        emit PaidMgp(projectId_, packageId_, msg.sender, amount_);
    }

    /**
     * @dev Sends approved Bonus to collaborator, should be called from collaborator's address
     * @param projectId_ Id of the project
     * @param packageId_ Id of the package
     */
    function getBonus(bytes32 projectId_, bytes32 packageId_) external nonReentrant returns (uint256 amount_) {
        address collaborator_ = msg.sender;
        require(approvedUser[projectId_][packageId_][collaborator_], "Only Collaborator Can Call!");
        Collaborator storage collaborator = collaboratorData[projectId_][packageId_][collaborator_];
        amount_ = collaborator.bonusScore;
        collaborator._claimBonus();
        packageData[projectId_][packageId_]._claimBonus(amount_);
        projectData[projectId_]._pay(collaborator_, amount_);
        emit PaidBonus(projectId_, packageId_, msg.sender, amount_);
    }

    /***************************************
			OBSERVER ACTIONS
	****************************************/

    /**
     * @dev Sends observer fee, should be called from observer's address
     * @param projectId_ Id of the project
     * @param packageId_ Id of the package
     * @return amount_ fee amount paid
     */
    function getObserverFee(bytes32 projectId_, bytes32 packageId_) external nonReentrant returns (uint256 amount_) {
        Observer storage observer = observerData[projectId_][packageId_][msg.sender];
        observer._claimObserverFee();
        amount_ = packageData[projectId_][packageId_]._getObserverFee();
        projectData[projectId_]._pay(msg.sender, amount_);
        emit PaidObserverFee(projectId_, packageId_, msg.sender, amount_);
    }

    function getProjectData(bytes32 projectId_) external view returns (Project memory) {
        return projectData[projectId_];
    }

    function getPackageData(bytes32 projectId_, bytes32 packageId_) external view returns (Package memory) {
        return (packageData[projectId_][packageId_]);
    }

    function getCollaboratorData(
        bytes32 projectId_,
        bytes32 packageId_,
        address collaborator_
    ) external view returns (Collaborator memory) {
        return collaboratorData[projectId_][packageId_][collaborator_];
    }

    function getObserverData(
        bytes32 projectId_,
        bytes32 packageId_,
        address observer_
    ) external view returns (Observer memory) {
        return observerData[projectId_][packageId_][observer_];
    }
}
