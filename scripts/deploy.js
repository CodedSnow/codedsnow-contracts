// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
    // ========== BASE LEVEL ==========
    // Deploy Authority
    const AuthContract = await ethers.getContractFactory("Authority");
    const auth = await AuthContract.deploy(
        deployer.address,
        deployer.address,
        deployer.address,
        deployer.address
    );

    console.log(`Deployed Authority: ${auth.address}`);

    // Deploy COD
    const CodContract = await ethers.getContractFactory("COD");
    const cod = await CodContract.deploy(auth.address);

    console.log(`Deployed COD: ${cod.address}`);

    // Deploy sCOD
    const sCodContract = await ethers.getContractFactory("sCOD");
    const scod = await sCodContract.deploy(auth.address);

    console.log(`Deployed sCOD: ${scod.address}`);

    // ========== BUILD LEVEL ==========
    // Deploy Treasury
    const TreasuryContract = await ethers.getContractFactory("Treasury");
    const treasury = await TreasuryContract.deploy(cod.address, process.env.DAI_TOKEN, auth.address);

    console.log(`Deployed Treasury: ${treasury.address}`);

    // Deploy Vault
    const VaultContract = await ethers.getContractFactory("Vault");
    const vault = await VaultContract.deploy(cod.address, scod.address, auth.address);

    console.log(`Deployed Vault: ${vault.address}`);

    // ========== ROOFTOP LEVEL ==========
    // Deploy presale
    const PresaleContract = await ethers.getContractFactory("Presale");
    const presale = await PresaleContract.deploy(cod.address, process.env.DAI_TOKEN, auth.address);

    console.log(`Deployed Presale: ${presale.address}`);

    const [deployer] = await ethers.getSigners();

    console.log(`\nDeployer: ${deployer.address}`);
    console.log(`Balance: ${ethers.utils.formatEther(await deployer.getBalance())} (ETH)`);

    // Distributing initial supply
    await cod.distSupply(presale.address, deployer.address);
    console.log('\n--------------[Initial Supply]--------------');
    console.log(`Presale: ${ethers.utils.formatUnits(await cod.balanceOf(presale.address), 'gwei')} (COD)`);
    console.log(`Team/Deployer: ${ethers.utils.formatUnits(await cod.balanceOf(deployer.address), 'gwei')} (COD)`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((ex) => {
    console.error(ex);
    process.exitCode = 1;
});
