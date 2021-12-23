# Hardhat
### Compile
``npx hardhat compile``
### Deploy
``npx hardhat run --network localhost scripts/deploy.ts``
### Accounts + balances
``npx hardhat accounts --network localhost``

# Deployment
### Steps:
-------------------------
1. Deploy COD()
2. Deploy sCOD()
-------------------------
3. Deploy Treasury(COD, sCOD)
4. COD: setTreasury(tAddr)
-------------------------
5. Deploy Vault(COD, sCOD, vAddr)
6. sCOD: setVault(vAddr)
7. Treasury: setVault(vAddr)
-------------------------
8. Deploy presale(COD, tAddr)
-------------------------