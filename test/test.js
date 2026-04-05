const CharityRegistry = artifacts.require('CharityRegistry');
const DonationVault = artifacts.require('DonationVault');
const AuditLogger = artifacts.require('AuditLogger');

contract('CharityChain', (accounts) => {

const admin = accounts[0];
const ngo1 = accounts[1];
const donor1 = accounts[3];

const toWei = (n) => web3.utils.toWei(String(n), 'ether');

let registry, vault, audit;

before(async () => {
    registry = await CharityRegistry.new({ from: admin });
    vault = await DonationVault.new(registry.address, { from: admin });
    audit = await AuditLogger.new(vault.address, { from: admin });
});

// CONTRACT 1 TESTS
it('sets admin correctly', async () => {
    assert.equal(await registry.admin(), admin);
});

it('admin can register NGO', async () => {
    const tx = await registry.registerNGO('TestNGO', 'Mission', ngo1, { from: admin });
    const log = tx.logs.find(l => l.event === 'NGORegistered');
    assert(log, 'NGORegistered event missing');
});

it('admin can create cause', async () => {
    const tx = await registry.createCause(
        1, 'Water', 'Desc', '■', toWei(5), { from: admin });
    assert(tx.logs.find(l => l.event === 'CauseCreated'));
});

it('non-admin cannot register NGO', async () => {
    try {
        await registry.registerNGO('x','y',donor1, { from: donor1 });
        assert.fail();
    } catch(e) { assert(e.message.includes('Admin only')); }
});

// CONTRACT 2 TESTS
it('donor can donate ETH', async () => {
    const tx = await vault.donate(1, { from: donor1, value: toWei(0.1) });
    assert(tx.logs.find(l => l.event === 'DonationMade'));
});

it('vault holds ETH after donation', async () => {
    const bal = await vault.getBalance();
    assert(bal > 0, 'Vault should hold ETH');
});

it('rejects zero-value donation', async () => {
    try {
        await vault.donate(1, { from: donor1, value: 0 });
        assert.fail();
    } catch(e) { assert(e.message.includes('Amount')); }
});

it('admin can release funds', async () => {
    // First verify NGO wallet
    await registry.verifyNGO(1, { from: admin });
    const tx = await vault.releaseFunds(1, 0, { from: admin });
    assert(tx.logs.find(l => l.event === 'FundsReleased'));
});

it('non-admin cannot release funds', async () => {
    try {
        await vault.releaseFunds(1, 0, { from: donor1 });
        assert.fail();
    } catch(e) { assert(e.message.includes('Admin only')); }
});

// CONTRACT 3 TESTS
it('admin can log donation', async () => {
    const tx = await audit.logDonation(
        donor1, 1, toWei(0.1), 'Test', { from: admin });
    assert(tx.logs.find(l => l.event === 'AuditEntryAdded'));
});

it('donor badge upgrades on milestones', async () => {
    await audit.logDonation(donor1, 1, toWei(0.5), '', { from: admin });

    const donor = await audit.getDonor(donor1);
    const tier = donor[0]; // ✅ FIXED HERE

    assert(Number(tier) >= 3, 'Should be GOLD or higher');
});

});