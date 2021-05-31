import { expect } from "./setup"

import { ethers } from "hardhat"
import { Contract, Signer } from 'ethers'

describe('ERC20', () => {
  let account1: Signer
  let account2: Signer
  let account3: Signer
  before(async () => {
    ;[account1, account2, account3] = await ethers.getSigners()
  })

  const name = 'Some Really Cool Token Name'
  const initialSupply = 10000000

  let ERC20: Contract
  beforeEach(async () => {
    ERC20 = await (await ethers.getContractFactory('ERC20'))
      .connect(account1)
      .deploy(initialSupply, name)
  })

  describe('the basics', () => {
    it('should have a name', async () => {
      expect(await ERC20.name()).to.equal(name)
    })

    it('should have a total supply equal to the initial supply', async () => {
      expect(await ERC20.totalSupply()).to.equal(initialSupply)
    })

    it("should give the initial supply to the creator's address", async () => {
      expect(await ERC20.balanceOf(await account1.getAddress())).to.equal(
        initialSupply
      )
    })
  })
})