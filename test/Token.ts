// This is an example test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

import { expect, use } from "chai";
import { BigNumber, Contract, Wallet } from "ethers";
import { ethers } from "hardhat";
import {NFTGame, SieveQuestions} from "../typechain";
import "hardhat/console.sol";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// `describe` is a Mocha function that allows you to organize your tests. It's
// not actually needed, but having your tests organized makes debugging them
// easier. All Mocha functions are available in the global scope.

// `describe` receives the name of a section of your test suite, and a callback.
// The callback must define the tests of that section. This callback can't be
// an async function.
describe("Token contract", function () {

let nftGame : NFTGame;
let sieveQuestions : SieveQuestions;
let wallets: SignerWithAddress[];

  beforeEach(async function () {
    const NFTGame = await ethers.getContractFactory("NFTGame");
    nftGame = await NFTGame.deploy()

    const Verifier = await ethers.getContractFactory("Verifier");
    const verifier = await Verifier.deploy()

    const SieveQuestions = await ethers.getContractFactory("SieveQuestions");
    sieveQuestions = await SieveQuestions.deploy(verifier.address, nftGame.address);

    nftGame.addGovernor(sieveQuestions.address);

    wallets = await ethers.getSigners();
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    
    it("add question", async function () {
      await sieveQuestions.addQuestion(ethers.utils.formatBytes32String("123"), 5);
    });

    it("register in game", async function () {
      const first = wallets[0];
      const second = wallets[1];

      await sieveQuestions.addQuestion(ethers.utils.formatBytes32String("123"), 5);
      await nftGame.connect(first).register(first.address, 0, sieveQuestions.address);
      await nftGame.connect(second).register(second.address, 0, sieveQuestions.address);

      const questionId = await nftGame.getLobbyQuestion(first.address);
      const res = await sieveQuestions.connect(first).callStatic.answerQuestion([2,2], [[2,2],[2, 2]], [2,2], questionId);
      console.log(res);
    });
  });
});
