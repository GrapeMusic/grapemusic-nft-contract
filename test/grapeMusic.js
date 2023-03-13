const {expect} = require("chai");
const {ethers} = require("hardhat");
const {time} = require("@nomicfoundation/hardhat-network-helpers");

describe("GrapeMusic", function () {
    let grapeMusic;
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let addr4;

    const whiteListStartTime = 1681430400;
    const publicStartTime = 1681530400;
    let timestamp = whiteListStartTime;
    const whiteListPrice = ethers.utils.parseEther("1.0");
    const publicPrice = ethers.utils.parseEther("5.0");

    beforeEach(async function () {
        const GrapeMusic = await ethers.getContractFactory("GrapeMusic");

        [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
        grapeMusic = await GrapeMusic.deploy("GrapeMusicNFT", "GMNFT", 50);

        await grapeMusic.deployed();
        expect(grapeMusic.address).to.a("string");
    });

    describe("Contract initialization", function () {
        beforeEach(async function () {
            await grapeMusic.setSaleConfig(whiteListStartTime, whiteListPrice, publicStartTime, publicPrice, 5);
            await grapeMusic.setWhiteList([addr2.address, addr3.address], [3, 3]);
        });
        it("Verify total quantity", async function () {
            const total = await grapeMusic.collectionSize();
            expect(parseInt(total)).to.equal(50);
        });

        it("Verify sales configuration", async function () {
            const saleConfig = await grapeMusic.saleConfig();
            expect(saleConfig.whiteListStartTime).to.equal(whiteListStartTime);
            expect(saleConfig.publicStartTime).to.equal(publicStartTime);
            expect(ethers.utils.formatEther(saleConfig.whiteListPrice)).to.equal("1.0");
            expect(ethers.utils.formatEther(saleConfig.publicPrice)).to.equal("5.0");
            expect(saleConfig.publicMaxNumber).to.equal(5);
        });

        it("Verify whitelist configuration", async function () {
            const num = await grapeMusic.whiteList(addr2.address);
            expect(parseInt(num)).to.equal(3);
        });
    });

    describe("NFT mint", function () {
        beforeEach(async function () {
            await grapeMusic.setSaleConfig(timestamp, whiteListPrice, timestamp + 86400, publicPrice, 5);
            await grapeMusic.setWhiteList([addr2.address, addr3.address], [3, 3]);
            await grapeMusic.setBaseURI("https://bafybeiayact7nceq5lsmd2aac46voyq3wgv623njbkd4u5o3vrbanpb6ga.ipfs.dweb.link/");
        });

        it("Verify white list mint", async function () {
            await time.increaseTo(whiteListStartTime);
            await expect(grapeMusic.connect(addr1).whiteListMint(1)).to.be.revertedWith("whiteListMint: Not eligible for whiteList mint");
            await expect(grapeMusic.connect(addr2).whiteListMint(4)).to.be.revertedWith(
                "whiteListMint: Exceeding the number of castings in the whiteList"
            );
            await grapeMusic.connect(addr2).whiteListMint(3, {value: ethers.utils.parseEther((3 * 1).toString())});
            const num = await grapeMusic.whiteList(addr2.address);
            expect(parseInt(num)).to.equal(0);
            timestamp = whiteListStartTime + 10;
        });

        it("Verify NFT address", async function () {
            await time.increaseTo(timestamp);
            await grapeMusic.connect(addr2).whiteListMint(1, {value: ethers.utils.parseEther((1 * 1).toString())});
            const url = await grapeMusic.tokenURI(0);
            expect(url).to.equal("https://bafybeiayact7nceq5lsmd2aac46voyq3wgv623njbkd4u5o3vrbanpb6ga.ipfs.dweb.link/0");
            timestamp = timestamp + 10;
        });

        it("Verify public sale mint", async function () {
            timestamp += 86400;
            await time.increaseTo(timestamp);
            await expect(grapeMusic.connect(addr2).publicSaleMint(6)).to.be.revertedWith("publicSaleMint: Can not mint this many");
            await grapeMusic.connect(addr1).publicSaleMint(5, {value: ethers.utils.parseEther((5 * 5).toString())});
            const num = await grapeMusic.numberMinted(addr1.address);
            expect(parseInt(num)).to.equal(5);
            timestamp = timestamp + 100;
        });

        it("Verify dev mint", async function () {
            await grapeMusic.connect(owner).devMint(owner.address);
            const num = await grapeMusic.numberMinted(owner.address);
            expect(parseInt(num)).to.equal(50);
        });
    });

    describe("Revenue recognition", function () {
        beforeEach(async function () {
            await grapeMusic.setProfit([addr3.address, addr4.address], [70, 30]);
            await grapeMusic.setSaleConfig(timestamp, whiteListPrice, timestamp + 86400, publicPrice, 5);
        });

        it("Verify Gain income", async function () {
            timestamp += 86400;
            await time.increaseTo(timestamp);
            await grapeMusic.connect(addr1).publicSaleMint(5, {value: ethers.utils.parseEther((5 * 5).toString())});
            await grapeMusic.connect(addr2).publicSaleMint(5, {value: ethers.utils.parseEther((5 * 5).toString())});

            const totalIncome = await grapeMusic.provider.getBalance(grapeMusic.address);
            expect(parseInt(totalIncome)).to.equal(50000000000000000000);

            await grapeMusic.withdrawMoney();
            const addr4Balance = await addr4.getBalance();
            const addr3Balance = await addr3.getBalance();
            expect(parseInt(addr4Balance)).to.equal(10015000000000000000000);
            expect(parseInt(addr3Balance)).to.equal(10035000000000000000000);
        });
    });
});
