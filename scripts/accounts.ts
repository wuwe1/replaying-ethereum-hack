import { ethers } from "hardhat";
import "@nomiclabs/hardhat-waffle";

async function main() {
  const signers = await ethers.getSigners();

  for (const account of signers) {
    console.log(`Address ${account.address}`);
    console.log("Account balance:", (await account.getBalance()).toString());
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
