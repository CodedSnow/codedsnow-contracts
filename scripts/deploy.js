import { ethers } from 'hardhat';

async function main() {
    const [deployer] = await ethers.getSigners();

    // ========== AUTHORITY ==========
    const AuthContract = await ethers.getContractFactory("Authority");
    const auth = await AuthContract.deploy(deployer.address);

    console.log(`Deployed Authority: ${auth.address}`);

    // ========== EPOCH ==========
    const EpochContract = await ethers.getContractFactory("Epoch");
    const epoch = await EpochContract.deploy(
        Math.floor(new Date().getTime() / 1000),
        auth.address
    );

    console.log(`Deployed Epoch: ${epoch.address}`);

    // ========== TOKENS ==========
    // === COD ===
    const CodContract = await ethers.getContractFactory("Cod");
    const cod = await CodContract.deploy(auth.address);

    console.log(`Deployed COD: ${cod.address}`);
    // === CBOND === 
    const CBondContract = await ethers.getContractFactory("CBond");
    const cbond = await CBondContract.deploy(auth.address);

    console.log(`Deployed CBOND: ${cbond.address}`);
    // === CSHARE ===
    const CShareContract = await ethers.getContractFactory("CShare");
    const cshare = await CShareContract.deploy(auth.address);

    console.log(`Deployed CSHARE: ${cshare.address}`);

    // ========== TREASURY ==========
    const TreasuryContract = await ethers.getContractFactory("Treasury");
    const treasury = await TreasuryContract.deploy(
        cod.address,
        cbond.address,
        epoch.address,
        process.env.MATIC_TOKEN,
        auth.address
    );
    await auth.pushTreasury(treasury.address, true);

    console.log(`Deployed Treasury: ${treasury.address}`);

    // ========== SHARES ==========

    // ========== STAKING ==========

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
