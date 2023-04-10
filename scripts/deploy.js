// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');
    const provider = new hre.ethers.providers.JsonRpcProvider(process.env.RINKEBY_URL);
    // 要查询的账户地址
    const wallet = new hre.ethers.Wallet(process.env.PRIVATE_KEY);

    // 获取余额
    const balanceBig = await provider.getBalance(wallet.address);
    const balance = hre.ethers.utils.formatEther(balanceBig);
    const feeData = await provider.getFeeData();

    console.log(`deploy wallet: ${wallet.address}\nwallet balance: ${balance} ETH`);
    // We get the contract to deploy
    const GrapeMusic = await hre.ethers.getContractFactory("GrapeMusic");
    const grapeMusic = await GrapeMusic.deploy("雙生花集", "雙生花集", 300);
    await grapeMusic.deployed();

    console.log("GrapeMusic deployed address:", grapeMusic.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
