# GrapeMusic NFT Contract

`Grape music NFT` contract project, mainly providing songs, albums, etc. Music NFT casting sales contracts

The project framework is based on `Hardhat`, which uses the `ERC721A` NFT protocol

Try running some of the following tasks:
```shell
cd grapemusic-nft-contract
npm install

npm run compile
npm run clean
npx hardhat run --network goerli scripts/deploy.js
npx hardhat verify --network goerli address --constructor-args scripts/arguments.js
# For more tasks, please check `npx hardhat`
```