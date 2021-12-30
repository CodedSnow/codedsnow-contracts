import { ethers } from 'hardhat';

async function main() {
    const [deployer] = await ethers.getSigners();

    // TODO: This
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((ex) => {
    console.error(ex);
    process.exitCode = 1;
});
