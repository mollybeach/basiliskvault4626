const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

    // Deploy PolicyManager first
    console.log("\nDeploying PolicyManager...");
    const PolicyManager = await hre.ethers.getContractFactory("PolicyManager");
    const policyManager = await PolicyManager.deploy();
    await policyManager.waitForDeployment();
    const policyManagerAddress = await policyManager.getAddress();
    console.log("PolicyManager deployed to:", policyManagerAddress);

    // Deploy BasiliskVault
    // Note: You'll need to deploy or use an existing ERC20 token as the underlying asset
    // For this example, we'll use a placeholder address - replace with actual token address
    const UNDERLYING_ASSET = process.env.UNDERLYING_ASSET || "0x0000000000000000000000000000000000000000";

    if (UNDERLYING_ASSET === "0x0000000000000000000000000000000000000000") {
        console.log("\n⚠️  WARNING: UNDERLYING_ASSET not set. Using zero address.");
        console.log("Set UNDERLYING_ASSET environment variable to deploy with a real token.");
    }

    console.log("\nDeploying BasiliskVault...");
    const BasiliskVault = await hre.ethers.getContractFactory("BasiliskVault");
    const vault = await BasiliskVault.deploy(
        UNDERLYING_ASSET,
        "Basilisk Vault Shares",
        "BVS",
        policyManagerAddress
    );
    await vault.waitForDeployment();
    const vaultAddress = await vault.getAddress();
    console.log("BasiliskVault deployed to:", vaultAddress);

    console.log("\n=== Deployment Summary ===");
    console.log("PolicyManager:", policyManagerAddress);
    console.log("BasiliskVault:", vaultAddress);
    console.log("Underlying Asset:", UNDERLYING_ASSET);
    console.log("\n✅ Deployment complete!");

    // Save deployment addresses (optional - you might want to use a deployment script library)
    console.log("\n💡 Tip: Save these addresses for your frontend/backend integration");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });