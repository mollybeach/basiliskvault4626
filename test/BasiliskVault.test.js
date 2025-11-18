const {
    expect
} = require("chai");
const {
    ethers
} = require("hardhat");

describe("BasiliskVault", function() {
    let vault;
    let policyManager;
    let underlyingToken;
    let owner;
    let depositor;

    beforeEach(async function() {
        [owner, depositor] = await ethers.getSigners();

        // Deploy a mock ERC20 token for testing
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        underlyingToken = await MockERC20.deploy("Test Token", "TEST", ethers.parseEther("1000000"));
        await underlyingToken.waitForDeployment();

        // Deploy PolicyManager
        const PolicyManager = await ethers.getContractFactory("PolicyManager");
        policyManager = await PolicyManager.deploy();
        await policyManager.waitForDeployment();

        // Deploy BasiliskVault
        const BasiliskVault = await ethers.getContractFactory("BasiliskVault");
        vault = await BasiliskVault.deploy(
            await underlyingToken.getAddress(),
            "Basilisk Vault Shares",
            "BVS",
            await policyManager.getAddress()
        );
        await vault.waitForDeployment();
    });

    describe("Deployment", function() {
        it("Should set the correct underlying asset", async function() {
            expect(await vault.asset()).to.equal(await underlyingToken.getAddress());
        });

        it("Should set the correct PolicyManager", async function() {
            expect(await vault.policyManager()).to.equal(await policyManager.getAddress());
        });
    });

    // Add more tests here as you develop the contracts
});