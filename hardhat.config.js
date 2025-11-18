require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.20",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    networks: {
        hardhat: {
            chainId: 1337,
        },
        rayls: {
            url: process.env.RAYLS_RPC_URL || "https://devnet-rpc.rayls.com",
            chainId: 123123,
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
            gasPrice: "auto",
        },
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
    },
    etherscan: {
        apiKey: {
            rayls: process.env.RAYLS_EXPLORER_API_KEY || "",
        },
        customChains: [{
            network: "rayls",
            chainId: 123123,
            urls: {
                apiURL: "https://devnet-explorer.rayls.com/api",
                browserURL: "https://devnet-explorer.rayls.com",
            },
        }, ],
    },
};