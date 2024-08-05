import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ArbitrageBot } from "../typechain-types";

describe("ArbitrageBot", function () {
  let arbitrageBot: ArbitrageBot;
  let owner: SignerWithAddress;
  let endpointAddress: string;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    const ArbitrageBotFactory = await ethers.getContractFactory("ArbitrageBot");
    endpointAddress = "0x1a44076050125825900e736c501f859c50fE728c";
    arbitrageBot = await ArbitrageBotFactory.deploy(endpointAddress);
    await arbitrageBot.deployed();
  });

  it("Should initialize the contract with the correct owner and endpoint", async function () {
    const contractOwner = await arbitrageBot.owner();
    const endpoint = await arbitrageBot.endpoint();
    console.log("Contract Owner:", contractOwner);
    console.log("Endpoint Address:", endpoint);

    expect(contractOwner).to.equal(owner.address);
    expect(endpoint).to.equal(endpointAddress);
  });

  it("Should set chain to arbitrage contract", async function () {
    const chainId = 42161; // Example chain ID
    const arbitrageContract = ethers.Wallet.createRandom().address;

    await arbitrageBot.setChainToArbitrageContract(chainId, arbitrageContract);

    const storedPeer = await arbitrageBot.peers(chainId);
    const expectedPeer = ethers.utils.hexZeroPad(arbitrageContract, 32);
    console.log("Stored Peer:", storedPeer);
    console.log("Expected Peer:", expectedPeer);

    expect(storedPeer).to.equal(expectedPeer);
  });

  it("Should execute cross-chain arbitrage", async function () {
    const tokens = ["0xaf88d065e77c8cC2239327C5EDb3A432268e5831", "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"];
    const amounts = [100 * 1e6, 1 * 1e18]; // Adjusted for token decimals
    const dexes = ["0x1F98431c8aD98523631AE4a59f267346ea31F984", "0xc35DADB65012eC5796536bD9864eD8773aBc74C4"];
    const bridges = ["0x0b2402144Bb366A632D14B83F244D2e0e21bD39c", "0x3a23F943181408EAC424116Af7b7790c94Cb97a5"];
    const chainIds = [1, 42161];
    const recipient = ethers.Wallet.createRandom().address;
    const nonce = 1;

    // Set peers for both chainIds
    await arbitrageBot.setChainToArbitrageContract(chainIds[0], ethers.Wallet.createRandom().address);
    await arbitrageBot.setChainToArbitrageContract(chainIds[1], ethers.Wallet.createRandom().address);

    // Create a valid signature
    const messageHash = await arbitrageBot.getMessageHash(tokens, amounts, dexes, bridges, chainIds, recipient, nonce);
    const ethSignedMessageHash = await arbitrageBot.getEthSignedMessageHash(messageHash);
    const signature = await owner.signMessage(ethers.utils.arrayify(ethSignedMessageHash));

    console.log("Message Hash:", messageHash);
    console.log("Ethereum Signed Message Hash:", ethSignedMessageHash);
    console.log("Signature:", signature);

    try {
      await arbitrageBot.executeCrossChainArbitrage(tokens, amounts, dexes, bridges, chainIds, recipient, nonce, signature, { value: ethers.utils.parseEther("1") });
    } catch (error) {
      console.error("Error executing cross-chain arbitrage:", error);
    }

    const arbParams = await arbitrageBot.getArbParams();
    console.log("Arbitrage Params:", arbParams);
    expect(arbParams.tokens).to.deep.equal(tokens);
    expect(arbParams.amounts).to.deep.equal(amounts);
    expect(arbParams.dexes).to.deep.equal(dexes);
    expect(arbParams.bridges).to.deep.equal(bridges);
    expect(arbParams.chainIds).to.deep.equal(chainIds);
    expect(arbParams.recipient).to.equal(recipient);
    expect(arbParams.nonce).to.equal(nonce);
    expect(arbParams.signature).to.equal(signature);
  });
});
