import { ethers } from 'hardhat';

async function main() {
    const [deployer] = await ethers.getSigners();

    // ========== BASE LEVEL ==========
    // Deploy Authority
    const AuthContract = await ethers.getContractFactory("Authority");
    const auth = await AuthContract.deploy(deployer.address);    

    console.log(`Deployed Authority: ${auth.address}`);

    // Deploy COD
    const CodContract = await ethers.getContractFactory("COD");
    const cod = await CodContract.deploy(auth.address);

    console.log(`Deployed COD: ${cod.address}`);

    // Deploy sCOD
    const bCodContract = await ethers.getContractFactory("bCOD");
    const bcod = await bCodContract.deploy(auth.address);

    console.log(`Deployed bCOD: ${bcod.address}`);

    // ========== BUILD LEVEL ==========
    // TODO: Deploy Treasury
    const TreasuryContract = await ethers.getContractFactory("Treasury");
    const treasury = await TreasuryContract.deploy(
        cod.address,
        bcod.address,
        process.env.MATIC_TOKEN,
        Math.floor(new Date().getTime() / 1000),
        auth.address
    );
    await auth.pushTreasury(deployer.address, true);

    console.log(`Deployed Treasury: ${treasury.address}`);

    // ========== ROOFTOP LEVEL ==========
    // Deploy presale
    const PresaleContract = await ethers.getContractFactory("Presale");
    const presale = await PresaleContract.deploy(cod.address, process.env.CONTRACTS_DAI_TOKEN, auth.address);

    console.log(`Deployed Presale: ${presale.address}`);

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
