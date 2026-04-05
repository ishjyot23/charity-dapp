// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './CharityRegistry.sol'; // Contract 1 imported here
import "./AuditLogger.sol"; 

contract DonationVault {

    address public admin;
    CharityRegistry public registry; // reference to Contract 1
    AuditLogger public audit;  

    struct Donation {
        uint256 id;
        address donor;
        uint256 causeId;
        uint256 amount; // in wei
        uint256 timestamp;
    }

    Donation[] public donations;
    uint256 public donationCount;
    uint256 public totalRaised;
    uint256 public totalReleased;

    mapping(uint256 => uint256) public causeRaised;   // causeId => wei
    mapping(uint256 => uint256) public causeReleased; // causeId => wei
    mapping(uint256 => uint256) public causeDonors;   // causeId => count
    mapping(address => uint256) public donorTotal;    // donor => wei

    // ■■ Events (LO4: each emit = Ganache block mined) ■■■■■■■■■■■■■
    event DonationMade(
        uint256 indexed id,
        address indexed donor,
        uint256 indexed causeId,
        uint256 amount,
        uint256 timestamp
    );

    event FundsReleased(
        uint256 indexed causeId,
        address ngoWallet,
        uint256 amount,
        address releasedBy
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    constructor(address _registry, address _audit) {
        admin = msg.sender;
        registry = CharityRegistry(_registry);
        audit = AuditLogger(_audit);
    }

    // ■■ DONATE — this is the function MetaMask signs ■■■■■■■■■■■■■■■
    // Every call: MetaMask popup → real ETH transfer → Ganache block
    function donate(uint256 _causeId) external payable {
        require(msg.value > 0, "Amount must be > 0");
        require(registry.isCauseActive(_causeId), "Cause not active");

        donationCount++;

        donations.push(
            Donation(
                donationCount,
                msg.sender,
                _causeId,
                msg.value,
                block.timestamp
            )
        );

        causeRaised[_causeId] += msg.value;
        donorTotal[msg.sender] += msg.value;
        totalRaised += msg.value;
        causeDonors[_causeId] += 1;

        emit DonationMade(
            donationCount,
            msg.sender,
            _causeId,
            msg.value,
            block.timestamp
        );
    }

    // ■■ RELEASE FUNDS — admin approved payout to NGO wallet ■■■■■■■■
    function releaseFunds(uint256 _causeId, uint256 _amount)
        external
        onlyAdmin
    {
        uint256 available = causeRaised[_causeId] - causeReleased[_causeId];
        require(available > 0, "No funds available");

        uint256 amt = (_amount == 0 || _amount > available) ? available : _amount;

        (, uint256 ngoId,,,,,) = registry.getCause(_causeId);
        (,, address ngoWallet,) = registry.getNGO(ngoId);
        require(ngoWallet != address(0), "Invalid NGO wallet");

        causeReleased[_causeId] += amt;
        totalReleased += amt;

        (bool ok,) = payable(ngoWallet).call{value: amt}("");
        require(ok, "Transfer failed");

        emit FundsReleased(_causeId, ngoWallet, amt, msg.sender);

        // 🔹 Add internal audit log call here
        audit.logActionInternal(msg.sender, "FUNDS_RELEASED", _causeId, amt);
    }

    // ■■ View functions ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

    function getCauseStats(uint256 _id)
        external
        view
        returns (
            uint256 raised,
            uint256 released,
            uint256 donors
        )
    {
        return (
            causeRaised[_id],
            causeReleased[_id],
            causeDonors[_id]
        );
    }

    function getDonation(uint256 _idx)
        external
        view
        returns (
            uint256,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        Donation memory d = donations[_idx];
        return (
            d.id,
            d.donor,
            d.causeId,
            d.amount,
            d.timestamp
        );
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ✅ New single transaction function
    function donateAndLog(uint256 _causeId) external payable {
        require(msg.value > 0, "Amount must be > 0");
        require(registry.isCauseActive(_causeId), "Cause not active");

        donationCount++;
        donations.push(Donation(donationCount, msg.sender, _causeId, msg.value, block.timestamp));

        causeRaised[_causeId] += msg.value;
        donorTotal[msg.sender] += msg.value;
        causeDonors[_causeId] += 1;
        totalRaised += msg.value;

        // Emit donation event
        emit DonationMade(donationCount, msg.sender, _causeId, msg.value, block.timestamp);

        // ✅ Audit log called inside same tx
        audit.logDonation(msg.sender, _causeId, msg.value, "Donation");
    }

    function setAuditLogger(address _audit) external onlyAdmin {
        require(_audit != address(0), "Invalid audit address");
        audit = AuditLogger(_audit);
    }
}