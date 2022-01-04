import { ethers } from 'hardhat';

async function main() {
    const [deployer] = await ethers.getSigners();

    // ========== AUTHORITY ==========
    const auth = await (await ethers.getContractFactory("Authority")).deploy(deployer.address);
    console.log(`Authority: '${auth.address}',`);

    // ========== TOKENS ==========
    const cod = await (await ethers.getContractFactory("Cod")).deploy(auth.address);
    console.log(`Cod: '${cod.address}',`);
    const cBond = await (await ethers.getContractFactory("CBond")).deploy(auth.address);
    console.log(`CBond: '${cBond.address}',`);
    const cShare = await (await ethers.getContractFactory("CShare")).deploy(auth.address);
    console.log(`CShare: '${cShare.address}',`);

    // ========== Treasury ==========
    const treasury = await (await ethers.getContractFactory("Treasury")).deploy(
        cod.address,
        cBond.address,
        cShare.address,
        Math.trunc(new Date().getTime() / 1000 + 1),
        auth.address
    );
    console.log(`Treasury: '${treasury.address}',`);

    // ========== Staking ==========
    const staking = await (await ethers.getContractFactory("Staking")).deploy(
        cod.address,
        cShare.address,
        treasury.address,
        auth.address
    );
    console.log(`Staking: '${staking.address}',`);
    // Set staking variable within treasury
    treasury.setStaking(staking.address);

    // ========== Pools ==========
    const shareRewardPool = await (await ethers.getContractFactory("CShareRewardPool")).deploy(
        cShare.address,
        Math.trunc(new Date().getTime() / 1000 + 1),
        auth.address
    );
    console.log(`ShareRewardPool: '${shareRewardPool.address}',`);


    // ========== Liquidity/Presale ==========
    // address _cod,
    // address _cshare,
    // address _treasury,
    // address _auth
    const liquidity = await (await ethers.getContractFactory("Liquidity")).deploy(
        cod.address,
        cShare.address,
        treasury.address,
        auth.address
    );
    console.log(`Liquidity: '${liquidity.address}',`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((ex) => {
    console.error(ex);
    process.exitCode = 1;
});
