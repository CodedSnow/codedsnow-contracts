import { ethers } from 'hardhat';
import { abi as liqAbi } from '../artifacts/contracts/Liquidity.sol/Liquidity.json';
import { abi as codAbi } from '../artifacts/contracts/Cod.sol/Cod.json';
import { abi as cshareAbi } from '../artifacts/contracts/CShare.sol/CShare.json';
import maticAbi from '../abis/WrappedMatic.json';
import addr from './_addr';

async function main() {
    const [deployer] = await ethers.getSigners();

    const liqCntr = new ethers.Contract(addr.Liquidity, liqAbi, deployer);
    const codCntr = new ethers.Contract(addr.Cod, codAbi, deployer);
    const cshareCntr = new ethers.Contract(addr.CShare, cshareAbi, deployer);
    const maticCntr = new ethers.Contract(addr.WrappedMatic, maticAbi, deployer);

    console.log('========== BEFORE ==========');
    console.log('MATIC: ' + ethers.utils.formatUnits(await deployer.getBalance()));
    console.log('wMATIC: ' + await maticCntr.functions.balanceOf(deployer.address) / 10e18);
    console.log('COD: ' + await codCntr.functions.balanceOf(deployer.address) / 10e18);
    console.log('cSHARE: ' + await cshareCntr.functions.balanceOf(deployer.address) / 10e18);

    // Get some matic
    await maticCntr.functions.deposit({ value: ethers.utils.parseUnits('1500') });
    await maticCntr.functions.approve(addr.Liquidity, ethers.utils.parseUnits('1500'));
    // Buy tokens
    console.log(await liqCntr.functions.codPool());
    await liqCntr.functions.buyCod(ethers.utils.parseUnits('100'));
    console.log(await liqCntr.functions.codPool());
    await liqCntr.functions.buyShare(ethers.utils.parseUnits('1'));

    console.log('========== AFTER ==========');
    console.log('MATIC: ' + ethers.utils.formatUnits(await deployer.getBalance()));
    console.log('wMATIC: ' + await maticCntr.functions.balanceOf(deployer.address) / 10e18);
    console.log('COD: ' + await codCntr.functions.balanceOf(deployer.address) / 10e18);
    console.log('cSHARE: ' + await cshareCntr.functions.balanceOf(deployer.address) / 10e18);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((ex) => {
    console.error(ex);
    process.exitCode = 1;
});
