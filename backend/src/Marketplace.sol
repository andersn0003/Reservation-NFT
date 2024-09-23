// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error Marketplace__PriceMustBeAboveZero();
error Marketplace__NotApprovedForMarketplace();
error Marketplace__AlreadyListed(uint256 tokenId);
error Marketplace__NotOwner();
error Marketplace__NotListed(uint256 tokenId);
error Marketplace__PriceNotMet(uint256 tokenId, uint256 price);
error Marketplace__NoProceeds();
error Marketplace__TransferFailed();
error Marketplace__ZeroAddress();

/// @title Marketplace
/// @notice A contract for buying and selling restaurant reservation NFTs
contract Marketplace is ReentrancyGuard, Ownable {
    address private reservNFTAddress;

    /// @notice Reservation data structure
    struct Listing {
        address seller;
        uint256 price;
    }

    event ReservationListed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );

    event ReservationBought(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price
    );

    event ReservationCancelled(address indexed seller, uint256 indexed tokenId);

    event ReservNFTAddressSet(address indexed reservNFTAddress);

    /// @notice Mapping from token ID to reservation listing data
    mapping(uint256 => Listing) private s_listings;

    /// @notice Mapping from token ID to proceeds
    mapping(address => uint256) private s_proceeds;

    /// @notice Check if the NFT is not listed
    /// @param tokenId The ID of the NFT
    modifier notListed(uint256 tokenId) {
        Listing memory listing = s_listings[tokenId];
        if (listing.price > 0) {
            revert Marketplace__AlreadyListed(tokenId);
        }
        _;
    }

    /// @notice Check if the NFT is owned by the spender
    /// @param tokenId The ID of the NFT
    /// @param spender The address of the spender
    modifier isOwner(uint256 tokenId, address spender) {
        IERC721 reserv = IERC721(reservNFTAddress);

        address owner = reserv.ownerOf(tokenId);

        if (spender != owner) {
            revert Marketplace__NotOwner();
        }
        _;
    }

    /// @notice Check if the NFT is listed
    /// @param tokenId The ID of the NFT
    modifier isListed(uint256 tokenId) {
        Listing memory listing = s_listings[tokenId];
        if (listing.price <= 0) {
            revert Marketplace__NotListed(tokenId);
        }
        _;
    }

    /// @notice Set the address of the ReservNFT contract
    /// @param _reservNFTAddress Address of the ReservNFT contract
    function setReservNFTAddress(address _reservNFTAddress) public onlyOwner {
        if (_reservNFTAddress == address(0)) {
            revert Marketplace__ZeroAddress();
        }

        reservNFTAddress = _reservNFTAddress;

        emit ReservNFTAddressSet(reservNFTAddress);
    }

    /// @notice List a reservation NFT for sale
    /// @param tokenId The ID of the NFT
    /// @param price The price of the NFT
    function listReservation(
        uint256 tokenId,
        uint256 price
    ) external notListed(tokenId) isOwner(tokenId, msg.sender) {
        if (price <= 0) {
            revert Marketplace__PriceMustBeAboveZero();
        }

        IERC721 reserv = IERC721(reservNFTAddress);

        if (reserv.getApproved(tokenId) != address(this)) {
            revert Marketplace__NotApprovedForMarketplace();
        }

        s_listings[tokenId] = Listing(msg.sender, price);
        emit ReservationListed(msg.sender, tokenId, price);
    }

    /// @notice Buy a reservation
    /// @param tokenId The ID of the NFT
    function buyReservation(
        uint256 tokenId
    ) external payable isListed(tokenId) nonReentrant {
        Listing memory listedReservation = s_listings[tokenId];

        if (msg.value < listedReservation.price) {
            revert Marketplace__PriceNotMet(tokenId, listedReservation.price);
        }

        s_proceeds[listedReservation.seller] =
            s_proceeds[listedReservation.seller] +
            msg.value;

        delete s_listings[tokenId];
        IERC721(reservNFTAddress).safeTransferFrom(
            listedReservation.seller,
            msg.sender,
            tokenId
        );

        emit ReservationBought(
            listedReservation.seller,
            msg.sender,
            tokenId,
            listedReservation.price
        );
    }

    /// @notice Cancel a reservation listing
    /// @param tokenId The ID of the NFT
    function cancelReservationListing(
        uint256 tokenId
    ) external isListed(tokenId) isOwner(tokenId, msg.sender) {
        Listing memory listedReservation = s_listings[tokenId];
        delete listedReservation;
        s_listings[tokenId] = listedReservation;
        emit ReservationCancelled(msg.sender, tokenId);
    }

    /// @notice Update a reservation listing
    /// @param tokenId The ID of the NFT
    /// @param newPrice The new price of the NFT
    function updateReservationListing(
        uint256 tokenId,
        uint256 newPrice
    ) external isListed(tokenId) isOwner(tokenId, msg.sender) {
        Listing memory listedReservation = s_listings[tokenId];
        listedReservation.price = newPrice;
        s_listings[tokenId] = listedReservation;

        emit ReservationListed(msg.sender, tokenId, newPrice);
    }

    function withdrawProceeds() external {
        uint256 amount = s_proceeds[msg.sender];

        if (amount <= 0) {
            revert Marketplace__NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert Marketplace__TransferFailed();
        }
    }

    /// @notice Get the listing data for a given token ID
    /// @param tokenId The ID of the NFT
    function getReservationListing(
        uint256 tokenId
    ) external view returns (Listing memory) {
        return s_listings[tokenId];
    }

    /// @notice Get the proceeds for a given seller
    /// @param seller The address of the seller
    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}
