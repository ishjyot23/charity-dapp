const CharityRegistry = artifacts.require('CharityRegistry');
const DonationVault = artifacts.require('DonationVault');
const AuditLogger = artifacts.require('AuditLogger');

module.exports = async function(deployer, network, accounts) {
    const admin = accounts[0]; // Ganache account[0] = deployer = admin

    // STEP 1: Deploy CharityRegistry (no dependencies)
    await deployer.deploy(CharityRegistry, { from: admin });
    const registry = await CharityRegistry.deployed();
    console.log('Registry:', registry.address);

    // STEP 2: Deploy DonationVault with ZERO address for audit (temporary)
    await deployer.deploy(DonationVault, registry.address, "0x0000000000000000000000000000000000000000", { from: admin });
    const vault = await DonationVault.deployed();
    console.log('Vault:', vault.address);

    // STEP 3: Deploy AuditLogger (needs vault address)
    await deployer.deploy(AuditLogger, vault.address, { from: admin });
    const audit = await AuditLogger.deployed();
    console.log('Audit:', audit.address);

    // STEP 4: Set the audit address in DonationVault
    await vault.setAuditLogger(audit.address, { from: admin });
    console.log('Audit address set in Vault');

    // SEED: Register 3 NGOs
    await registry.registerNGO('WaterAid Foundation',
        'Clean water for rural India', accounts[1], { from: admin });
    await registry.verifyNGO(1, { from: admin });

    await registry.registerNGO('Hope & Light NGO',
        'Education for underprivileged children', accounts[2], { from: admin });
    await registry.verifyNGO(2, { from: admin });

    await registry.registerNGO('Disaster Response India',
        'Emergency relief for flood victims', accounts[3], { from: admin });
    await registry.verifyNGO(3, { from: admin });

    // SEED: Create 3 causes
    const toWei = (n) => web3.utils.toWei(String(n), 'ether');
    await registry.createCause(1, 'Clean Water for Rural India',
        'Borehole drilling for 50,000 people in Maharashtra',
        '■', toWei(5), { from: admin });

    await registry.createCause(2, 'Education for Street Children',
        '3 schools + 200 scholarships in Mumbai',
        '■', toWei(8), { from: admin });

    await registry.createCause(3, 'Flood Relief — Assam 2025',
        'Emergency aid for 10,000 displaced families',
        '■', toWei(12), { from: admin });

    console.log('Seeded: 3 NGOs + 3 causes');
};