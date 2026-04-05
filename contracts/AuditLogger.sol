// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './DonationVault.sol'; // Contract 2 imported here

contract AuditLogger {

    address public admin;
    address public vault;


    // Badge tiers based on total ETH donated
    uint256 public constant BRONZE = 0.01 ether;
    uint256 public constant SILVER = 0.1 ether;
    uint256 public constant GOLD   = 0.5 ether;
    uint256 public constant DIAMOND = 1.0 ether;

    enum BadgeTier { NONE, BRONZE, SILVER, GOLD, DIAMOND }

    struct DonorProfile {
        BadgeTier tier;
        uint256 totalGiven;
        uint256 donationCount;
        uint256 firstDonation;
        bool exists;
    }

    struct AuditEntry {
        uint256 id;
        string action; // 'DONATION', 'RELEASE', 'CAUSE_CREATED'
        address actor;
        uint256 causeId;
        uint256 amount;
        uint256 timestamp;
        bytes32 dataHash; // integrity hash
    }

    mapping(address => DonorProfile) public donors;
    AuditEntry[] public auditLog;
    uint256 public auditCount;

    // ■■ Events ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    event AuditEntryAdded(
        uint256 indexed id,
        string action,
        address indexed actor,
        uint256 amount
    );

    event BadgeUpgraded(address indexed donor, BadgeTier newTier);
    event MilestoneReached(address indexed donor, string milestone);

    modifier onlyAuthorized() {
        require(
            msg.sender == vault || msg.sender == admin,
            "Not authorized"
        );
        _;
    }

    constructor(address _vault) {
        admin = msg.sender;
        vault = _vault;
    }
        

    // Log a donation + update donor profile + badge
    function logDonation(
        address _donor,
        uint256 _causeId,
        uint256 _amount,
        string memory _note
    ) external onlyAuthorized {

        auditCount++;

        bytes32 txHash = keccak256(
            abi.encodePacked(_donor, _causeId, _amount, block.timestamp)
        );

        auditLog.push(
            AuditEntry(
                auditCount,
                "DONATION",
                _donor,
                _causeId,
                _amount,
                block.timestamp,
                txHash
            )
        );

        emit AuditEntryAdded(auditCount, "DONATION", _donor, _amount);

        _updateDonor(_donor, _amount);
    }

    function logAction(
        string memory _action,
        uint256 _causeId,
        uint256 _amount
    ) external onlyAuthorized {

        bytes32 h = keccak256(
            abi.encodePacked(msg.sender, _action, _causeId, block.timestamp)
        );

        auditCount++;

        auditLog.push(
            AuditEntry(
                auditCount,
                _action,
                msg.sender,
                _causeId,
                _amount,
                block.timestamp,
                h
            )
        );

        emit AuditEntryAdded(auditCount, _action, msg.sender, _amount);
    }

    function _updateDonor(address _donor, uint256 _amount) internal {
        DonorProfile storage p = donors[_donor];

        if (!p.exists) {
            p.exists = true;
            p.firstDonation = block.timestamp;
            emit MilestoneReached(_donor, "FIRST_DONATION");
        }

        p.totalGiven += _amount;
        p.donationCount += 1;

        BadgeTier nb = _badge(p.totalGiven);

        if (nb > p.tier) {
            p.tier = nb;
            emit BadgeUpgraded(_donor, nb);
        }
    }

    function _badge(uint256 t) internal pure returns (BadgeTier) {
        if (t >= DIAMOND) return BadgeTier.DIAMOND;
        if (t >= GOLD)    return BadgeTier.GOLD;
        if (t >= SILVER)  return BadgeTier.SILVER;
        if (t >= BRONZE)  return BadgeTier.BRONZE;
        return BadgeTier.NONE;
    }

    function getDonor(address _d)
        external
        view
        returns (
            uint8 tier,
            uint256 total,
            uint256 count,
            uint256 first
        )
    {
        DonorProfile memory p = donors[_d];
        return (uint8(p.tier), p.totalGiven, p.donationCount, p.firstDonation);
    }

    function getEntry(uint256 _i)
        external
        view
        returns (
            uint256,
            string memory,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        AuditEntry memory e = auditLog[_i];
        return (e.id, e.action, e.actor, e.causeId, e.amount, e.timestamp);
    }
    // Make it external and restricted to DonationVault only
    function logActionInternal(
        address _actor,
        string memory _action,
        uint256 _causeId,
        uint256 _amount
    ) external {
        // Only allow the linked DonationVault to call this
        require(msg.sender == address(vault), "Only Vault can log");

        bytes32 h = keccak256(abi.encodePacked(_actor, _action, _causeId, block.timestamp));
        auditCount++;

        auditLog.push(
            AuditEntry(auditCount, _action, _actor, _causeId, _amount, block.timestamp, h)
        );

        emit AuditEntryAdded(auditCount, _action, _actor, _amount);
    }
}