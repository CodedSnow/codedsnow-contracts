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