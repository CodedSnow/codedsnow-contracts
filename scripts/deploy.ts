// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // Deploy COD
    const CodContract = await ethers.getContractFactory("COD");
    const cod = await CodContract.deploy();

    console.log(`Deployed COD: ${cod.address}`);

    // Deploy sCOD
    const sCodContract = await ethers.getContractFactory("sCOD");
    const scod = await sCodContract.deploy();

    console.log(`Deployed sCOD: ${scod.address}`);

    // Deploy Treasury
    const TreasuryContract = await ethers.getContractFactory("Treasury");
    const treasury = await TreasuryContract.deploy(cod.address, process.env.DAI_TOKEN as string);
    await cod.setTreasury(treasury.address);

    console.log(`Deployed Treasury: ${treasury.address}`);

    // Deploy Vault
    const VaultContract = await ethers.getContractFactory("Vault");
    const vault = await VaultContract.deploy(cod.address, scod.address, treasury.address);
    await scod.setVault(vault.address);
    await treasury.setVault(vault.address);

    console.log(`Deployed Vault: ${vault.address}`);

    // Deploy presale
    const PresaleContract = await ethers.getContractFactory("Presale");
    const presale = await PresaleContract.deploy(cod.address, process.env.DAI_TOKEN as string, treasury.address);

    console.log(`Deployed Presale: ${presale.address}`);

    const [owner] = await ethers.getSigners();
    console.log(`\nOwner: ${owner.address}`);
    console.log(`Balance: ${ethers.utils.formatEther(await owner.getBalance())} (ETH)`);

    // Distributing initial supply
    await cod.distSupply(presale.address, owner.address);
    console.log('\n--------------[Initial Supply]--------------');
    console.log(`Presale: ${ethers.utils.formatUnits(await cod.balanceOf(presale.address), 'gwei')} (COD)`);
    console.log(`Team/Owner: ${ethers.utils.formatUnits(await cod.balanceOf(owner.address), 'gwei')} (COD)`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((ex) => {
    console.error(ex);
    process.exitCode = 1;
});
