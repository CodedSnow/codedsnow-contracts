import { ethers } from 'hardhat';
import { abi as codAbi } from '../artifacts/contracts/Cod.sol/Cod.json';
import { abi as cshareAbi } from '../artifacts/contracts/CShare.sol/CShare.json';
import addr from './_addr';

async function main() {
    const [deployer] = await ethers.getSigners();

    // ========== COD ==========
    const codCntr = new ethers.Contract(addr.Cod, codAbi, deployer);
    await codCntr.functions.distSupply(addr.Liquidity, deployer.address).catch(console.log);

    // ========== cSHARE ==========
    const cshareCntr = new ethers.Contract(addr.CShare, cshareAbi, deployer);
    cshareCntr.functions.distSupply(addr.Treasury, addr.Liquidity, addr.ShareRewardPool).catch(console.log);

    console.log('========== DISTRIBUTED ==========');
    console.log(`COD:\n - Liquidity (${await codCntr.functions.balanceOf(addr.Liquidity) / 10e18})\n - Airdrop (${await codCntr.functions.balanceOf(deployer.address) / 10e18})`);
    console.log(`cSHARE:\n - Treasury (${await cshareCntr.functions.balanceOf(addr.Treasury) / 10e18})\n - Liquidity (${await cshareCntr.functions.balanceOf(addr.Liquidity) / 10e18})\n - RewardPool (${await cshareCntr.functions.balanceOf(addr.ShareRewardPool) / 10e18})`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((ex) => {
    console.error(ex);
    process.exitCode = 1;
});
