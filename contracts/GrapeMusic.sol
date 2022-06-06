// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

//   _____                     ___  ___          _
//  |  __ \                    |  \/  |         (_)
//  | |  \/_ __ __ _ _ __   ___| .  . |_   _ ___ _  ___
//  | | __| '__/ _` | '_ \ / _ \ |\/| | | | / __| |/ __|
//  | |_\ \ | | (_| | |_) |  __/ |  | | |_| \__ \ | (__
//   \____/_|  \__,_| .__/ \___\_|  |_/\__,_|___/_|\___|
//                 | |
//                 |_|

contract GrapeMusic is ERC721A, Ownable, ReentrancyGuard {
    uint256 public immutable maxPerAddressDuringMint;
    uint256 public immutable auctionMaxSize;
    uint256 public immutable collectionSize;

    struct SaleConfig {
        uint32 auctionSaleStartTime;
        uint32 publicSaleStartTime;
        uint64 mintlistPrice;
        uint64 publicPrice;
        uint32 publicSaleKey;
    }

    SaleConfig public saleConfig;

    mapping(address => uint256) public whitelist;
    mapping(address => uint256) public beneficiarylist;

    address[] public withdrawAddress;
    uint256[] public shares;

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxAddressBatchSize_,
        uint256 collectionSize_,
        uint256 auctionMaxSize_
    ) ERC721A(name, symbol) {
        maxPerAddressDuringMint = maxAddressBatchSize_;
        collectionSize = collectionSize_;
        auctionMaxSize = auctionMaxSize_;
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    // auction mint
    function auctionMint(uint256 quantity) external payable callerIsUser {
        uint256 _saleStartTime = uint256(saleConfig.auctionSaleStartTime);
        require(_saleStartTime != 0 && block.timestamp >= _saleStartTime, "sale has not started yet");
        require(totalSupply() + quantity <= auctionMaxSize, "the number of auctions has reached the upper limit");
        require(numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint, "reaches the upper limit of personal casting");
        uint256 totalCost = getAuctionPrice(_saleStartTime) * quantity;
        _safeMint(msg.sender, quantity);
        refundIfOver(totalCost);
    }

    // white list mint
    function whitelistMint(uint256 quantity) external payable callerIsUser {
        uint256 price = uint256(saleConfig.mintlistPrice);
        require(price != 0, "whitelist sale has not begun yet");
        require(whitelist[msg.sender] > 0, "not eligible for whitelist mint");
        require(whitelist[msg.sender] >= quantity, "exceeding the number of castings in the whitelist");
        require(totalSupply() + quantity <= collectionSize, "reached max supply");
        for (uint256 i = 0; i < quantity; i++) {
            whitelist[msg.sender]--;
        }
        _safeMint(msg.sender, quantity);
        refundIfOver(price * quantity);
    }

    // public sale mint
    function publicSaleMint(uint256 quantity, uint256 callerPublicSaleKey) external payable callerIsUser {
        SaleConfig memory config = saleConfig;
        uint256 publicSaleKey = uint256(config.publicSaleKey);
        uint256 publicPrice = uint256(config.publicPrice);
        uint256 publicSaleStartTime = uint256(config.publicSaleStartTime);
        require(publicSaleKey == callerPublicSaleKey, "called with incorrect public sale key");
        require(isPublicSaleOn(publicPrice, publicSaleKey, publicSaleStartTime), "public sale has not begun yet");
        require(totalSupply() + quantity <= collectionSize, "reached max supply");
        require(numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint, "can not mint this many");
        _safeMint(msg.sender, quantity);
        refundIfOver(publicPrice * quantity);
    }

    // Refund if over
    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "Need to send more ETH.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    // Determining whether to start a public sale
    function isPublicSaleOn(
        uint256 publicPriceWei,
        uint256 publicSaleKey,
        uint256 publicSaleStartTime
    ) public view returns (bool) {
        return publicPriceWei != 0 && publicSaleKey != 0 && block.timestamp >= publicSaleStartTime;
    }

    uint256 public constant AUCTION_START_PRICE = 1 ether;
    uint256 public constant AUCTION_END_PRICE = 0.15 ether;
    uint256 public constant AUCTION_PRICE_CURVE_LENGTH = 340 minutes;
    uint256 public constant AUCTION_DROP_INTERVAL = 20 minutes;
    uint256 public constant AUCTION_DROP_PER_STEP = (AUCTION_START_PRICE - AUCTION_END_PRICE) / (AUCTION_PRICE_CURVE_LENGTH / AUCTION_DROP_INTERVAL);

    // Get auction price
    function getAuctionPrice(uint256 _saleStartTime) public view returns (uint256) {
        if (block.timestamp < _saleStartTime) {
            return AUCTION_START_PRICE;
        }
        if (block.timestamp - _saleStartTime >= AUCTION_PRICE_CURVE_LENGTH) {
            return AUCTION_END_PRICE;
        } else {
            uint256 steps = (block.timestamp - _saleStartTime) / AUCTION_DROP_INTERVAL;
            return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
        }
    }

    // Set initial data configuration
    function setupSaleInfo(
        uint64 mintlistPrice,
        uint64 publicPrice,
        uint32 publicSaleStartTime
    ) external onlyOwner {
        saleConfig = SaleConfig(0, publicSaleStartTime, mintlistPrice, publicPrice, saleConfig.publicSaleKey);
    }

    // Send the remaining amount of NFTs to the wallet
    function devMint(address devAddress, uint256 quantity) external onlyOwner {
        require(devAddress != address(0), "address cannot be empty");
        require(quantity > 0, "quantity cannot be less than or equal to 0");
        uint256 leftOver = collectionSize - totalSupply();
        while (leftOver > 10) {
            _safeMint(devAddress, 10);
            leftOver -= 10;
        }
        if (leftOver > 0) {
            _safeMint(devAddress, leftOver);
        }
    }

    // Set the Dutch beat start time
    function setAuctionSaleStartTime(uint32 timestamp) external onlyOwner {
        saleConfig.auctionSaleStartTime = timestamp;
    }

    // Set public mint key
    function setPublicSaleKey(uint32 key) external onlyOwner {
        saleConfig.publicSaleKey = key;
    }

    // Set up a whitelist
    function setWhiteList(address[] memory addresses, uint256[] memory numSlots) external onlyOwner {
        require(addresses.length == numSlots.length, "addresses does not match numSlots length");
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = numSlots[i];
        }
    }

    // Set up share account and ratio
    function setBeneficiaryList(address[] memory addresses, uint256[] memory numShares) external onlyOwner {
        require(addresses.length == numShares.length, "addresses does not match numScaleSlots length");
        for (uint256 i = 0; i < addresses.length; i++) {
            withdrawAddress.push(addresses[i]);
            shares.push(numShares[i]);
        }
    }

    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        require(withdrawAddress.length != 0, "No beneficiary address");
        uint256 balance = address(this).balance;
        for (uint256 i = 0; i < withdrawAddress.length; i++) {
            uint256 amount = balance * (shares[i] / 100);
            payable(withdrawAddress[i]).transfer(amount);
        }
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId) external view returns (TokenOwnership memory) {
        return _ownershipOf(tokenId);
    }
}
