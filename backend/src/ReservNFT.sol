// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

import {IRestaurantManager} from "../interfaces/IRestaurantManager.sol";

error ReservNFT__InsufficientPayment();
error ReservNFT__InactiveDrop();
error ReservNFT__OutsideDropWindow();
error ReservNFT__ExceedReservationsLimit();
error ReservNFT__Unauthorized();
error ReservNFT__NonexistentToken();
error ReservNFT__OutsideDailyWindow();
error ReservNFT__InvalidWindowDuration();
error ReservNFT__NoBalanceAvailable();
error ReservNFT__ZeroAddress();
error ReservNFT__TransferFailed();

/// @title ReservNFT
/// @notice A contract for creating restaurant reservation NFTs with different drops and mint prices.
contract ReservNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _tokenIds;

    address private restaurantManagerAddress;
    // Mapping from token ID to reservation data
    mapping(uint256 => Reservation) public reservations;
    mapping(address => uint256) public ownerBalances;

    /// @notice Reservation data structure
    struct Reservation {
        uint256 restaurantId;
        uint256 dropId;
        uint256 reservationTimestamp; // Represents both date and time
    }

    event ReservationCreated(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed restaurantId,
        uint256 dropId,
        uint256 reservationTimestamp
    );

    event RestaurantManagerAddressSet(address indexed restaurantManagerAddress);

    constructor() ERC721("ReservNFT", "RRNFT") {}

    /// @notice Generates the metadata JSON for the reservation NFT
    /// @param restaurantId The unique identifier of the restaurant
    /// @param reservationTimestamp The timestamp of the reservation
    function generateMetadataJson(
        uint256 restaurantId,
        uint256 reservationTimestamp
    ) internal pure returns (string memory) {
        // Define the imageURI based on your desired image
        string
            memory imageURI = "https://cdn.onlinewebfonts.com/svg/img_481205.png";

        // Generate metadata JSON
        string memory metadataJson = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"Reservation NFT", "description":"Restaurant reservation NFT", "attributes":[{"trait_type":"restaurantId","value":',
                            Strings.toString(restaurantId),
                            '},{"trait_type":"reservationTimestamp","value":',
                            Strings.toString(reservationTimestamp),
                            '}], "image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );

        return metadataJson;
    }

    /// @notice Sets the address of the RestaurantManager contract
    /// @param _restaurantManagerAddress The address of the RestaurantManager contract
    function setRestaurantManagerAddress(
        address _restaurantManagerAddress
    ) public onlyOwner {
        if (_restaurantManagerAddress == address(0)) {
            revert ReservNFT__ZeroAddress();
        }
        restaurantManagerAddress = _restaurantManagerAddress;

        emit RestaurantManagerAddressSet(_restaurantManagerAddress);
    }

    /// @notice Creates a reservation NFT
    /// @param dropId The unique identifier of the drop
    /// @param reservationTimestamp The timestamp of the reservation
    function createReservNFT(
        uint256 dropId,
        uint256 reservationTimestamp
    ) public payable nonReentrant returns (uint256) {
        IRestaurantManager restaurantManager = IRestaurantManager(
            restaurantManagerAddress
        );
        IRestaurantManager.Drop memory drop = restaurantManager.getDrop(dropId);

        if (!drop.isActive) {
            revert ReservNFT__InactiveDrop();
        }

        if (msg.value < drop.mintPrice) {
            revert ReservNFT__InsufficientPayment();
        }

        uint256 secondsSinceMidnight = reservationTimestamp % 86400;

        // Check if the reservation timestamp is before the daily start time or after the daily end time
        if (
            secondsSinceMidnight < drop.dailyStartTime ||
            secondsSinceMidnight > drop.dailyEndTime
        ) {
            revert ReservNFT__OutsideDailyWindow();
        }

        // Check if the reservation timestamp is within the drop window
        if (
            reservationTimestamp < drop.startDate ||
            reservationTimestamp > drop.endDate
        ) {
            revert ReservNFT__OutsideDropWindow();
        }

        // Check if the reservation timestamp falls on the specified window duration boundary
        uint256 secondsSinceDailyStart = secondsSinceMidnight -
            drop.dailyStartTime;
        if (secondsSinceDailyStart % drop.windowDuration != 0) {
            revert ReservNFT__InvalidWindowDuration();
        }

        uint256 reservationCount = restaurantManager
            .getTimeSlotReservationCount(dropId, reservationTimestamp);

        if (reservationCount >= drop.reservationsPerWindow) {
            revert ReservNFT__ExceedReservationsLimit();
        }

        string memory metadataJson = generateMetadataJson(
            drop.restaurantId,
            reservationTimestamp
        );

        _tokenIds += 1;
        uint256 newItemId = _tokenIds;

        reservations[newItemId] = Reservation(
            drop.restaurantId,
            dropId,
            reservationTimestamp
        );

        restaurantManager.setTimeSlotReservationCount(
            dropId,
            reservationTimestamp,
            reservationCount + 1
        );

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, metadataJson);

        emit ReservationCreated(
            msg.sender,
            newItemId,
            drop.restaurantId,
            dropId,
            reservationTimestamp
        );

        // Transfer mint fee to restaurant owner
        ownerBalances[
            restaurantManager.getRestaurant(drop.restaurantId).owner
        ] += drop.mintPrice;

        // Handle mint price and refund any overpayment
        if (msg.value > drop.mintPrice) {
            uint256 refundAmount = msg.value - drop.mintPrice;
            payable(msg.sender).transfer(refundAmount);
        }

        return newItemId;
    }

    /// @notice Withdraws the balance of the restaurant owner
    function withdrawRestaurantOwnerBalance() public nonReentrant {
        uint256 balance = ownerBalances[msg.sender];

        if (balance <= 0) {
            revert ReservNFT__NoBalanceAvailable();
        }

        ownerBalances[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert ReservNFT__TransferFailed();
        }
    }

    /// @notice Retrieves the details of a reservation
    /// @param tokenId The unique identifier of the reservation NFT
    /// @return A Reservation struct containing the reservation details
    function getReservationDetails(
        uint256 tokenId
    ) public view returns (Reservation memory) {
        return reservations[tokenId];
    }
}
