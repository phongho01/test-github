const { ethers, network, run } = require("hardhat");
import { LilPudgys__factory, LilPudgys } from "../typechain-types";
import { Table } from "./utils";

const table = new Table();

async function main() {
	const LilPudgys_factory = (await ethers.getContractFactory("LilPudgys")) as LilPudgys__factory;

	console.log("============DEPLOYING CONTRACTS============");

	const lilPudgy: LilPudgys = await LilPudgys_factory.deploy("Lil Pudgys", "LP");
	await lilPudgy.deployed();
	table.add([{ name: "Lil Pudgys", type: "deploy", address: lilPudgy.address }]);
	table.log();

	// console.log("============SAVE CONTRACTS ADDRESS============");
	// await table.save("deployed", `nft_test_${network.name}_${Date.now()}.json`);

	console.log("============VERIFY CONTRACTS============");
	await run("verify:verify", {
		address: lilPudgy.address,
		constructorArguments: ["Lil Pudgys", "LP"],
	}).catch(console.log);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});

