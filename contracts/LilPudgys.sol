// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import { IERC721, ERC721, ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev This contract is using for testing create course with external NFT Contract
 */
contract LilPudgys is ERC721URIStorage, Ownable {
    event Minted(address to, uint256 tokenId, string uri);

    /**
     * @notice ID of Minted NFT, increase by 1
     */
    uint256 public tokenIds;

    /**
     * @notice Function called when contract is deployed
     * @param name Name of NFT
     * @param symbol Symbol of NFT
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /**
     * @notice mint a NFT for _to address
     * @param _to address of user
     * @param _uri Ipfs link of NFT
     * 
     * emit { Minted } events
     */
    function mint(address _to, string memory _uri) external onlyOwner {
        require(_to != address(0), "Invalid address");
        tokenIds++;
        _safeMint(_to, tokenIds);
        _setTokenURI(tokenIds, _uri);

        emit Minted(_to, tokenIds, _uri);
    }

    function mintBatch(string[] memory _uris) external onlyOwner {
        for(uint256 i = 0; i < _uris.length; i++) {
            tokenIds++;
            _safeMint(_msgSender(), tokenIds);
            _setTokenURI(tokenIds, _uris[i]);
        }
    }

    function burn(uint256[] memory _tokenIds) external onlyOwner {
        for(uint256 i = 0; i < _tokenIds.length; i++) {
            _burn(_tokenIds[i]);
        }
    }
}