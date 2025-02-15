// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _totalMinted;
    mapping(uint256 => address) private _owners; // Track token owners
    mapping(address => uint256[]) private _ownedTokens; // Track tokens owned by an address
    uint256[] private _allTokens; // Store all minted tokens
    mapping(uint256 => string) private _tokenURIs; // Token metadata URIs
    mapping(uint256 => uint256) private _mintBlockNumbers; // Minting block numbers
    mapping(uint256 => uint256) private _mintTimestamps; // Minting timestamps
    mapping(uint256 => string) private _mintTxHashes; // Minting transaction hashes

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
        _totalMinted++;
        _owners[tokenId] = to;
        _ownedTokens[to].push(tokenId);
        _allTokens.push(tokenId);
        _mintBlockNumbers[tokenId] = block.number;
        _mintTimestamps[tokenId] = block.timestamp;
    }

    function totalNFTMinted() public view returns (uint256) {
        return _totalMinted;
    }

    function findTokenByAddress(address owner) public view returns (uint256[] memory) {
        return _ownedTokens[owner];
    }

    function findAddressByTokenId(uint256 tokenId) public view returns (address) {
        return ownerOf(tokenId);
    }

    function listAllToken() public view returns (uint256[] memory) {
        return _allTokens;
    }

    function getAllTokenMetadataByAddressMinted(address owner) public view returns (string memory) {
        uint256[] memory tokenIds = _ownedTokens[owner];
        uint256 length = tokenIds.length;
        string memory json = "[";

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            json = string(abi.encodePacked(
                json,
                i > 0 ? "," : "",
                "{",
                '"contract": {',
                '"address": "', toHexString(address(this)), '",',
                '"name": "', name(), '",',
                '"symbol": "', symbol(), '",',
                '"totalSupply": null,',
                '"tokenType": "ERC721",',
                '"contractDeployer": "', toHexString(owner), '",',
                '"deployedBlockNumber": null,',
                '"openSeaMetadata": {',
                '"floorPrice": null,',
                '"collectionName": null,',
                '"collectionSlug": null,',
                '"safelistRequestStatus": null,',
                '"imageUrl": null,',
                '"description": null,',
                '"externalUrl": null,',
                '"twitterUsername": null,',
                '"discordUrl": null,',
                '"bannerImageUrl": null,',
                '"lastIngestedAt": null',
                "},",
                '"isSpam": null,',
                '"spamClassifications": []',
                "},",
                '"tokenId": "', uintToString(tokenId), '",',
                '"tokenType": "ERC721",',
                '"name": null,',
                '"description": null,',
                '"tokenUri": null,',
                '"image": {',
                '"cachedUrl": null,',
                '"thumbnailUrl": null,',
                '"pngUrl": null,',
                '"contentType": null,',
                '"size": null,',
                '"originalUrl": null',
                "},",
                '"raw": {',
                '"tokenUri": null,',
                '"metadata": {},',
                '"error": null',
                "},",
                '"collection": null,',
                '"mint": {',
                '"mintAddress": "', toHexString(owner), '",',
                '"blockNumber": "', uintToString(_mintBlockNumbers[tokenId]), '",',
                '"timestamp": "', uintToString(_mintTimestamps[tokenId]), '",',
                '"transactionHash": null',
                "},",
                '"owners": null,',
                '"timeLastUpdated": null,',
                '"balance": "1",',
                '"acquiredAt": {',
                '"blockTimestamp": null,',
                '"blockNumber": null',
                "}",
                "}"
            ));
        }

        json = string(abi.encodePacked(json, "]"));
        return json;
    }

    function uintToString(uint256 v) internal pure returns (string memory) {
        if (v == 0) {
            return "0";
        }
        uint256 temp = v;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (v != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + v % 10));
            v /= 10;
        }
        return string(buffer);
    }

    function toHexString(address account) internal pure returns (string memory) {
        return toHexString(uint256(uint160(account)), 20);
    }

    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = bytes1(uint8(48 + (value & 0xf)));
            if ((value & 0xf) > 9) {
                buffer[i] = bytes1(uint8(87 + (value & 0xf))); // Convert to hex
            }
            value >>= 4;
        }
        return string(buffer);
    }
}
