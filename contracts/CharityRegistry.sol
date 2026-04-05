// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CharityRegistry {

    address public admin;
    uint256 public ngoCount;
    uint256 public causeCount;

    struct NGO {
        uint256 id;
        string name;
        string mission;
        address wallet; // NGO receives released funds here
        bool verified;
        bool exists;
    }

    struct Cause {
        uint256 id;
        uint256 ngoId;
        string name;
        string description;
        string emoji;
        uint256 goalWei; // donation goal in wei
        bool active;
        bool exists;
    }

    mapping(uint256 => NGO) public ngos;
    mapping(uint256 => Cause) public causes;

    // ■■ Events (audit trail) ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    event NGORegistered(
        uint256 indexed ngoId,
        string name,
        address wallet
    );

    event CauseCreated(
        uint256 indexed causeId,
        uint256 ngoId,
        string name,
        uint256 goalWei
    );

    event CauseClosed(uint256 indexed causeId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Admin registers a verified NGO
    function registerNGO(
        string memory _name,
        string memory _mission,
        address _wallet
    ) external onlyAdmin returns (uint256) {

        require(_wallet != address(0), "Invalid wallet");

        ngoCount++;

        ngos[ngoCount] = NGO(
            ngoCount,
            _name,
            _mission,
            _wallet,
            false,
            true
        );

        emit NGORegistered(ngoCount, _name, _wallet);

        return ngoCount;
    }

    function verifyNGO(uint256 _id) external onlyAdmin {
        require(ngos[_id].exists, "NGO not found");
        ngos[_id].verified = true;
    }

    // Admin creates a fundraising cause under an NGO
    function createCause(
        uint256 _ngoId,
        string memory _name,
        string memory _desc,
        string memory _emoji,
        uint256 _goalWei
    ) external onlyAdmin returns (uint256) {

        require(ngos[_ngoId].exists, "NGO not found");
        require(_goalWei > 0, "Goal must be > 0");

        causeCount++;

        causes[causeCount] = Cause(
            causeCount,
            _ngoId,
            _name,
            _desc,
            _emoji,
            _goalWei,
            true,
            true
        );

        emit CauseCreated(causeCount, _ngoId, _name, _goalWei);

        return causeCount;
    }

    function closeCause(uint256 _id) external onlyAdmin {
        causes[_id].active = false;
        emit CauseClosed(_id);
    }

    // ■■ View functions ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

    function getCause(uint256 _id)
        external
        view
        returns (
            uint256,
            uint256,
            string memory,
            string memory,
            string memory,
            uint256,
            bool
        )
    {
        Cause memory c = causes[_id];
        return (
            c.id,
            c.ngoId,
            c.name,
            c.emoji,
            c.description,
            c.goalWei,
            c.active
        );
    }

    function getNGO(uint256 _id)
        external
        view
        returns (
            string memory,
            string memory,
            address,
            bool
        )
    {
        NGO memory n = ngos[_id];
        return (n.name, n.mission, n.wallet, n.verified);
    }

    function isCauseActive(uint256 _id) external view returns (bool) {
        return causes[_id].exists && causes[_id].active;
    }

    // New combined function for one-click cause creation
    function registerAndCreateCause(
        string memory _ngoName,
        string memory _ngoMission,
        address _ngoWallet,
        string memory _causeName,
        string memory _causeDesc,
        string memory _causeEmoji,
        uint256 _goalWei
    ) external onlyAdmin returns (uint256) {
        require(_ngoWallet != address(0), "Invalid wallet");
        require(_goalWei > 0, "Goal must be > 0");

        // Register NGO
        ngoCount++;
        ngos[ngoCount] = NGO(ngoCount, _ngoName, _ngoMission, _ngoWallet, true, true);
        emit NGORegistered(ngoCount, _ngoName, _ngoWallet);

        // Create Cause under that NGO
        causeCount++;
        causes[causeCount] = Cause(
            causeCount,
            ngoCount,
            _causeName,
            _causeDesc,
            _causeEmoji,
            _goalWei,
            true,
            true
        );
        emit CauseCreated(causeCount, ngoCount, _causeName, _goalWei);

        return causeCount;
    }
}