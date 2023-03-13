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
    mapping(address => uint64) public whiteList; // White list
    uint256 public immutable collectionSize; // Total issuance of NFTs.

    address[] public profitAccount; // Address participating in profit sharing.
    uint256[] public profitProportion; // Profit sharing ratio of participating accounts.
    string private baseTokenURI; // NFT base url

    struct SaleConfig {
        uint32 whiteListStartTime; // White list sale start time
        uint64 whiteListPrice; // White list sale price
        uint32 publicStartTime; // Public sale start time
        uint64 publicPrice; // Public sale price
        uint256 publicMaxNumber; // Maximum public number
    }
    SaleConfig public saleConfig;

    constructor(string memory name, string memory symbol, uint256 collectionSize_) ERC721A(name, symbol) {
        collectionSize = collectionSize_;
    }

    // Verify if the caller is a real user.
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    // Refund for amount exceeded.
    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "refundIfOver: Insufficient account balance.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    /**
     * @dev whiteList mint
     * @param quantity {uint64} Mint quantity
     */
    function whiteListMint(uint64 quantity) external payable callerIsUser {
        uint64 price = uint64(saleConfig.whiteListPrice);
        uint32 whiteListStartTime = uint32(saleConfig.whiteListStartTime);
        require(block.timestamp >= whiteListStartTime, "whiteListMint: whiteList sale has not begun yet");
        require(whiteList[msg.sender] > 0, "whiteListMint: Not eligible for whiteList mint");
        require(whiteList[msg.sender] >= quantity, "whiteListMint: Exceeding the number of castings in the whiteList");
        require(totalSupply() + quantity <= collectionSize, "whiteListMint: Exceeding maximum supply limit");
        for (uint256 i = 0; i < quantity; i++) {
            whiteList[msg.sender]--;
        }
        _safeMint(msg.sender, quantity);
        refundIfOver(price * quantity);
    }

    /**
     * @dev Public sale mint
     * @param quantity {uint64} Mint quantity
     */
    function publicSaleMint(uint256 quantity) external payable callerIsUser {
        uint256 publicPrice = uint256(saleConfig.publicPrice);
        uint32 publicStartTime = uint32(saleConfig.publicStartTime);
        uint256 publicMaxNumber = uint256(saleConfig.publicMaxNumber);
        require(block.timestamp >= publicStartTime, "publicSaleMint: Public sale has not begun yet");
        require(totalSupply() + quantity <= collectionSize, "publicSaleMint: Exceeding maximum supply limit");
        require(numberMinted(msg.sender) + quantity <= publicMaxNumber, "publicSaleMint: Can not mint this many");
        _safeMint(msg.sender, quantity);
        refundIfOver(publicPrice * quantity);
    }

    /**
     * @dev Batch mint remaining NFTs
     * @param dev       {address}
     */
    function devMint(address dev) external onlyOwner {
        require(dev != address(0), "devMint: Address cannot be empty");
        uint256 leftOver = collectionSize - totalSupply();
        while (leftOver > 10) {
            _safeMint(dev, 10);
            leftOver -= 10;
        }
        if (leftOver > 0) {
            _safeMint(dev, leftOver);
        }
    }

    /**
     * @dev Number minted
     * @param owner {uint64} owner Query address
     * @return {uint256} NFT number
     */
    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    /**
     * @dev Set sales information
     * @param whiteListStartTime    {uint32} White list start time
     * @param whiteListPrice        {uint64} White sales price
     * @param publicStartTime   {uint32} Public sales start time
     * @param publicPrice       {uint64} Public sales price
     * @param publicMaxNumber   {uint256} Public sales max number
     */
    function setSaleConfig(
        uint32 whiteListStartTime,
        uint64 whiteListPrice,
        uint32 publicStartTime,
        uint64 publicPrice,
        uint256 publicMaxNumber
    ) external onlyOwner {
        require(whiteListStartTime > block.timestamp, "setSaleConfig: whiteListStartTime <= timestamp");
        require(publicStartTime > block.timestamp, "setSaleConfig: publicStartTime <= timestamp");
        require(whiteListPrice >= 0, "setSaleConfig: whiteListPrice <= 0");
        require(publicPrice >= 0, "setSaleConfig: publicPrice <= 0");
        require(publicMaxNumber > 0, "setSaleConfig: publicMaxNumber <= 0");
        saleConfig = SaleConfig(whiteListStartTime, whiteListPrice, publicStartTime, publicPrice, publicMaxNumber);
    }

    /**
     * @dev Set white list
     * @param list          {address[]} White list address
     * @param numberSlots   {uint256[]}   Configuration of the casting quantity for white sheets.
     */
    function setWhiteList(address[] memory list, uint64[] memory numberSlots) external onlyOwner {
        require(list.length == numberSlots.length, "setWhiteList: The list does not match the quantity.");
        for (uint256 i = 0; i < list.length; i++) {
            whiteList[list[i]] = numberSlots[i];
        }
    }

    /**
     * @dev set profit info
     * @param participationAddress      {address[]}  List of Divided Accounts
     * @param numberSlots               {uint256[]}  Proportion of revenue sharing account
     */
    function setProfit(address[] calldata participationAddress, uint256[] calldata numberSlots) external onlyOwner {
        require(participationAddress.length == numberSlots.length, "setProfit: The list does not match the quantity.");
        for (uint256 i = 0; i < participationAddress.length; i++) {
            profitAccount.push(participationAddress[i]);
            profitProportion.push(numberSlots[i]);
        }
    }

    // NFT base url
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev set NFT base url
     * @param baseURI      {string} NFT meatData url
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        baseTokenURI = baseURI;
    }

    // Withdraw the contract amount
    function withdrawMoney() external onlyOwner nonReentrant {
        require(profitAccount.length != 0, "withdrawMoney: No profit account address");
        uint256 balance = address(this).balance;
        for (uint256 i = 0; i < profitAccount.length; i++) {
            uint256 amount = (balance * profitProportion[i]) / 100;
            payable(profitAccount[i]).transfer(amount);
        }
    }
}
