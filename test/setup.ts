import chai, { expect } from "chai";
import { waffle } from "hardhat";
const { solidity } = waffle;

chai.use(solidity);

export { expect };
