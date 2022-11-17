// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

interface IVaultManager {
    function balanceOf(address _renter, address _NFTaddr) external view returns(uint256);
    function tokenOfRenterByIndex(address _renter, address _NFTaddr, uint _index) external view returns(uint256);
    function renterOfToken(address _NFTaddr,uint _tokenID) external view returns(address);
}

contract RentNFTUpgradeable is OwnableUpgradeable, ERC721EnumerableUpgradeable {
    address public rentManager;
    mapping(address => bool) public authContracts;

    function setRentManager(address _manager) external onlyOwner {
        require(_manager != address(0));
        rentManager = _manager;
    }

    function setAuthContracts(address _contracts, bool _enable) external onlyOwner {
        authContracts[_contracts] = _enable;
    }

    function balanceOf(address owner) public view override(ERC721Upgradeable, IERC721Upgradeable) returns (uint256 balance) {
        return super.balanceOf(owner) + IVaultManager(rentManager).balanceOf(owner, address(this));
    }

    function ownerOf(uint256 tokenId) public view override(ERC721Upgradeable, IERC721Upgradeable) returns (address) {
        address owner = super.ownerOf(tokenId);
        if (owner == rentManager) {
            owner = IVaultManager(rentManager).renterOfToken(address(this), tokenId);
        }
        return owner;
    }

    function renterOf(uint256 tokenId) public view returns (address) {
        if (super.ownerOf(tokenId) == rentManager) {
            return IVaultManager(rentManager).renterOfToken(address(this), tokenId);
        }
        return address(0);
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        if (index < super.balanceOf(owner)) {
            return super.tokenOfOwnerByIndex(owner, index);
        }

        index = index - super.balanceOf(owner);
        return IVaultManager(rentManager).tokenOfRenterByIndex(owner, address(this), index);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        // Hardcode the Auth controllers's approval so that users don't have to waste gas approving
        if (authContracts[_msgSender()] == false)
            require(_isApprovedOrOwner(_msgSender(), tokenId), "isApprovedOrOwner false");
        if (renterOf(tokenId) == from) {
            from = rentManager;
        } else if (renterOf(tokenId) == to) {
            to = rentManager;
        }
        _transfer(from, to, tokenId);
    }
}
