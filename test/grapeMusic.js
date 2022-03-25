const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("GrapeMusic", function () {
    let grapeMusic;
    let owner;
    let addr1;
    let addr2;
    let addr3;

    beforeEach(async function () {
        const GrapeMusic = await ethers.getContractFactory("GrapeMusic");

        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        grapeMusic = await GrapeMusic.deploy("GrapeMusicNFT", "GMNFT", 8, 20, 10);

        await grapeMusic.deployed();
        expect(grapeMusic.address).to.a("string");
    });

    describe("initialization contract parameters", function () {
        let saleConfig;
        beforeEach(async function () {
            await grapeMusic.setupSaleInfo(ethers.utils.parseEther("0.01"), ethers.utils.parseEther("0.2"), 1646150400);
            await grapeMusic.setAuctionSaleStartTime(1646064000);
            await grapeMusic.setPublicSaleKey(2022);

            saleConfig = await grapeMusic.saleConfig();
        });

        it("initialization contract parameters", async function () {
            expect(ethers.utils.formatUnits(await grapeMusic.auctionMaxSize(), 0)).to.equal("10");
            expect(ethers.utils.formatUnits(await grapeMusic.collectionSize(), 0)).to.equal("20");
            expect(ethers.utils.formatUnits(await grapeMusic.maxPerAddressDuringMint(), 0)).to.equal("8");
        });

        it("set sales information", async function () {
            expect(saleConfig.mintlistPrice).to.equal(ethers.utils.parseEther("0.01").toString());
            expect(saleConfig.publicPrice).to.equal(ethers.utils.parseEther("0.2").toString());
            expect(saleConfig.publicSaleStartTime).to.equal(1646150400);
        });

        it("set auction sale start time", async function () {
            expect(saleConfig.auctionSaleStartTime).to.equal(1646064000);
        });

        it("set public sale key", async function () {
            expect(saleConfig.publicSaleKey).to.equal(2022);
        });
    });

    describe("mint nft", function () {
        it("white list mint", async function () {
            await grapeMusic.setupSaleInfo(ethers.utils.parseEther("0.01"), ethers.utils.parseEther("0.2"), 1646150400);
            await expect(grapeMusic.setWhiteList([owner.address, addr1.address], [2])).to.be.revertedWith("addresses does not match numSlots length");
            await grapeMusic.setWhiteList([owner.address, addr1.address], [2, 2]);

            expect(await grapeMusic.whitelist(owner.address)).to.equal(2);
            await expect(grapeMusic.whitelistMint({value: 0})).to.be.revertedWith("Need to send more ETH.");
            await grapeMusic.whitelistMint({value: ethers.utils.parseEther("0.01")});
            await grapeMusic.whitelistMint({value: ethers.utils.parseEther("0.01")});
            expect(await grapeMusic.balanceOf(owner.address)).to.be.equal(2);
            await expect(grapeMusic.whitelistMint({value: ethers.utils.parseEther("0.01")})).to.be.revertedWith("not eligible for whitelist mint");
        });

        it("auction mint", async function () {
            await expect(grapeMusic.auctionMint(1, {value: ethers.utils.parseEther("1")})).to.be.revertedWith("sale has not started yet");
            await grapeMusic.setAuctionSaleStartTime(1646064000);

            await expect(grapeMusic.auctionMint(12, {value: ethers.utils.parseEther("12")})).to.be.revertedWith(
                "the number of auctions has reached the upper limit"
            );
            await grapeMusic.connect(addr1).auctionMint(8, {value: ethers.utils.parseEther("8")});
            expect(await grapeMusic.balanceOf(addr1.address)).to.be.equal(8);
        });

        it("public sale mint", async function () {
            await expect(grapeMusic.publicSaleMint(1, 2022, {value: ethers.utils.parseEther("0.2")})).to.be.revertedWith(
                "called with incorrect public sale key"
            );
            await grapeMusic.setPublicSaleKey(2022);
            await expect(grapeMusic.publicSaleMint(1, 2022, {value: ethers.utils.parseEther("0.2")})).to.be.revertedWith(
                "public sale has not begun yet"
            );
            await grapeMusic.setupSaleInfo(ethers.utils.parseEther("0.01"), ethers.utils.parseEther("0.2"), 1646150400);

            await expect(grapeMusic.publicSaleMint(1, 2022, {value: 0})).to.be.revertedWith("Need to send more ETH.");
            await expect(grapeMusic.publicSaleMint(1, 1234, {value: ethers.utils.parseEther("0.2")})).to.be.revertedWith(
                "called with incorrect public sale key"
            );
            await expect(grapeMusic.publicSaleMint(10, 2022, {value: ethers.utils.parseEther("2")})).to.be.revertedWith("can not mint this many");
            await expect(grapeMusic.publicSaleMint(21, 2022, {value: ethers.utils.parseEther("2.1")})).to.be.revertedWith("reached max supply");
        });

        it("get meta data", async function () {
            await grapeMusic.setBaseURI("https://gateway.pinata.cloud/ipfs/QmXhedcvqyky1F6VHNfZkENzfvwGr4gZ9GseBmKKn3nLkc/");
            await grapeMusic.setupSaleInfo(ethers.utils.parseEther("0.01"), ethers.utils.parseEther("0.2"), 1646150400);
            await grapeMusic.setWhiteList([owner.address, addr1.address], [2, 2]);

            await grapeMusic.whitelistMint({value: ethers.utils.parseEther("0.01")});

            expect(await grapeMusic.tokenURI(0)).to.be.equal("https://gateway.pinata.cloud/ipfs/QmXhedcvqyky1F6VHNfZkENzfvwGr4gZ9GseBmKKn3nLkc/0");
        });

        it("withdraw money", async function () {
            await grapeMusic.setAuctionSaleStartTime(1646064000);
            await grapeMusic.auctionMint(8, {value: ethers.utils.parseEther("8")});

            await expect(grapeMusic.withdrawMoney()).to.be.revertedWith("No beneficiary address");
            await grapeMusic.setBeneficiaryList([addr2.address, addr3.address], [50, 50]);

            const provider = ethers.provider;
            const tx = await grapeMusic.withdrawMoney();
            await tx.wait();

            expect(await provider.getBalance(addr2.address)).to.be.equal(ethers.utils.parseEther("10000.6"));
            expect(await provider.getBalance(addr2.address)).to.be.equal(ethers.utils.parseEther("10000.6"));
        });
    });
});
