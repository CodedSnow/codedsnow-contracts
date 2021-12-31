import { expect } from "chai";
import { ethers } from "hardhat";

const COD_ADDR = "";
const PRESALE_ADDR = "";
const TEAM_ADDR = "";

describe("Distributer", function () {
    it("Should distribute the initial supply of COD", async function () {
        const cod = (await ethers.getContractFactory('COD')).attach(COD_ADDR);

        // Distribute the tokens
        const distSupply = await cod.distSupply(PRESALE_ADDR, TEAM_ADDR);

        // Wait until the transaction is mined
        await distSupply.wait();

        // Check balance of presale
        expect(cod.balanceOf(PRESALE_ADDR)).to.equal(50000 * (10**9));
        expect(cod.balanceOf(TEAM_ADDR)).to.equal(6000 * (10**9));
    });
});