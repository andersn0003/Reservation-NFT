// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IReservNFT} from "../interfaces/IReservNFT.sol";

error RestaurantManager__Unauthorized();
error RestaurantManager__DropAlreadyExists();
error RestaurantManager__NotReservNFT();
error RestaurantManager__DropDoesNotExist();
error RestaurantManager__RestaurantDoesNotExist();
error RestaurantManager__InvalidDropDates();
error RestaurantManager__InvalidDropTimes();
error RestaurantManager__ZeroAddress();

/// @title RestaurantManager
/// @notice Register and manage restaurants
contract RestaurantManager is Ownable {
    uint256 private _restaurantCounter;
    uint256 private _dropCounter;

    address private reservNFTAddress;

    mapping(uint256 => Restaurant) public restaurants;
    mapping(uint256 => Drop) public drops;
    mapping(uint256 => mapping(uint256 => uint256))
        public dropToTimeSlotReservationCount;
    mapping(uint256 => uint256) public restaurantDropCount;

    /// @dev Restaurant struct stores restaurant information
    struct Restaurant {
        address owner;
        string name;
        string businessAddress;
        bool isActive;
    }

    /// @notice Drop data structure
    struct Drop {
        uint256 dropId;
        uint256 restaurantId;
        uint256 mintPrice;
        uint64 startDate; // start date in unix timestamp
        uint64 endDate; // end date in unix timestamp
        uint32 dailyStartTime; // Represented in seconds i.e. 8 am = 28800
        uint32 dailyEndTime; // Represented in seconds i.e. 10 pm = 36000
        uint32 windowDuration; // Duration of each reservation window in seconds i.e. hourly = 3600
        uint16 reservationsPerWindow; // Number of reservations per window i.e. 10 reservations per window
        bool isActive;
    }

    /// @notice Event emitted when a restaurant is registered
    /// @param restaurantId The unique identifier of the registered restaurant
    /// @param owner The address of the restaurant owner
    /// @param name The name of the restaurant
    /// @param businessAddress The business address of the restaurant
    event RestaurantRegistered(
        uint256 indexed restaurantId,
        address indexed owner,
        string name,
        string businessAddress
    );

    event ReservNFTAddressSet(address indexed reservNFTAddress);

    /// @notice Event emitted when a drop is created
    /// @param dropId The unique identifier of the created drop
    /// @param restaurantId The unique identifier of the associated restaurant
    /// @param mintPrice The mint price of the reservation NFT for the drop
    /// @param startDate The start timestamp of the drop
    /// @param endDate The end timestamp of the drop
    /// @param dailyStartTime The daily start time of the drop in seconds
    /// @param dailyEndTime The daily end time of the drop in seconds
    /// @param windowDuration The duration of each reservation window in seconds
    /// @param reservationsPerWindow The number of reservations allowed per window
    event DropCreated(
        uint256 indexed dropId,
        uint256 indexed restaurantId,
        uint256 mintPrice,
        uint64 startDate,
        uint64 endDate,
        uint32 dailyStartTime,
        uint32 dailyEndTime,
        uint32 windowDuration,
        uint16 reservationsPerWindow
    );

    /// @notice Event emitted when a restaurant's active status is toggled
    /// @param restaurantId The unique identifier of the restaurant
    /// @param isActive The active status of the restaurant
    event RestaurantIsActive(uint256 indexed restaurantId, bool isActive);

    /// @notice Event emitted when a drop's active status is toggled
    /// @param dropId The unique identifier of the drop
    /// @param isActive The active status of the drop
    event DropIsActive(uint256 indexed dropId, bool isActive);

    modifier onlyReservNFT() {
        if (msg.sender != reservNFTAddress) {
            revert RestaurantManager__NotReservNFT();
        }
        _;
    }

    modifier onlyRestaurantOwner(uint256 restaurantId) {
        if (msg.sender != restaurants[restaurantId].owner) {
            revert RestaurantManager__Unauthorized();
        }
        _;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @return Documents the return variables of a contract’s function state variable
    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)ow

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @return Documents the return variables of a contract’s function state variable
    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)o

    /// @notice Set the address of the ReservNFT contract
    /// @param _reservNFTAddress Address of the ReservNFT contract
    function setReservNFTAddress(address _reservNFTAddress) public onlyOwner {
        if (_reservNFTAddress == address(0)) {
            revert RestaurantManager__ZeroAddress();
        }

        reservNFTAddress = _reservNFTAddress;

        emit ReservNFTAddressSet(reservNFTAddress);
    }

    /// @notice Register a restaurant
    /// @param name Restaurant name
    /// @param businessAddress Restaurant location
    function registerRestaurant(
        string calldata name,
        string calldata businessAddress
    ) public {
        uint256 restaurantId = _restaurantCounter;
        restaurants[restaurantId] = Restaurant({
            owner: msg.sender,
            name: name,
            businessAddress: businessAddress,
            isActive: true
        });
        ++_restaurantCounter;

        emit RestaurantRegistered(
            restaurantId,
            msg.sender,
            name,
            businessAddress
        );
    }

    /// @notice changes status of a restaurant by its ID
    /// @param restaurantId Restaurant ID
    function setRestaurantIsActive(
        uint256 restaurantId,
        bool isActive
    ) public onlyRestaurantOwner(restaurantId) {
        Restaurant storage restaurant = restaurants[restaurantId];

        restaurant.isActive = isActive;
        emit RestaurantIsActive(restaurantId, isActive);
    }

    /// @notice Get a restaurant by its ID
    /// @param restaurantId Restaurant ID
    /// @return Restaurant struct
    function getRestaurant(
        uint256 restaurantId
    ) public view returns (Restaurant memory) {
        if (restaurantId >= _restaurantCounter) {
            revert RestaurantManager__RestaurantDoesNotExist();
        }
        return restaurants[restaurantId];
    }

    /// @notice Creates a new drop with the given parameters
    /// @param restaurantId The unique identifier of the restaurant
    /// @param mintPrice The price to mint a reservation NFT for this drop
    /// @param startDate The start timestamp of the drop
    /// @param endDate The end timestamp of the drop
    /// @param dailyStartTime The start time of the drop in seconds
    /// @param dailyEndTime The end time of the drop in seconds
    /// @param windowDuration The duration of each reservation window in seconds
    /// @param reservationsPerWindow The number of reservations per window
    function createDrop(
        uint256 restaurantId,
        uint256 mintPrice,
        uint64 startDate,
        uint64 endDate,
        uint32 dailyStartTime,
        uint32 dailyEndTime,
        uint32 windowDuration,
        uint16 reservationsPerWindow
    ) public onlyRestaurantOwner(restaurantId) {
        if (startDate >= endDate) {
            revert RestaurantManager__InvalidDropDates();
        }

        uint256 newDropId = _dropCounter;

        if (drops[newDropId].isActive) {
            revert RestaurantManager__DropAlreadyExists();
        }

        ++_dropCounter;

        ++restaurantDropCount[restaurantId];

        drops[newDropId] = Drop({
            dropId: newDropId,
            restaurantId: restaurantId,
            mintPrice: mintPrice,
            startDate: startDate,
            endDate: endDate,
            dailyStartTime: dailyStartTime,
            dailyEndTime: dailyEndTime,
            windowDuration: windowDuration,
            reservationsPerWindow: reservationsPerWindow,
            isActive: true
        });

        emit DropCreated(
            newDropId,
            restaurantId,
            mintPrice,
            startDate,
            endDate,
            dailyStartTime,
            dailyEndTime,
            windowDuration,
            reservationsPerWindow
        );
    }

    function setDropIsActive(uint256 dropId, bool isActive) public {
        Drop storage drop = drops[dropId];
        uint256 restaurantId = drop.restaurantId;

        if (msg.sender != restaurants[restaurantId].owner) {
            revert RestaurantManager__Unauthorized();
        }

        drop.isActive = isActive;
        emit DropIsActive(dropId, isActive);
    }

    /// @notice Retrieves the details of a drop
    /// @param dropId The unique identifier of the drop
    /// @return A Drop struct containing the drop details
    function getDrop(uint256 dropId) public view returns (Drop memory) {
        if (dropId >= _dropCounter) {
            revert RestaurantManager__DropDoesNotExist();
        }

        return drops[dropId];
    }

    /// @notice Retrieves the drop IDs associated with a specific restaurant.
    /// @param restaurantId The unique identifier of the restaurant.
    /// @return result
    function getDropIDsByRestaurant(
        uint256 restaurantId
    ) public view returns (uint[] memory result) {
        result = new uint[](restaurantDropCount[restaurantId]);
        uint counter = 0;

        for (uint i = 0; i < _dropCounter; i++) {
            if (drops[i].restaurantId == restaurantId) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    function getTimeSlotReservationCount(
        uint256 dropId,
        uint256 reservationTimestamp
    ) public view returns (uint256) {
        return dropToTimeSlotReservationCount[dropId][reservationTimestamp];
    }

    function setTimeSlotReservationCount(
        uint256 dropId,
        uint256 reservationTimestamp,
        uint256 count
    ) external onlyReservNFT {
        dropToTimeSlotReservationCount[dropId][reservationTimestamp] = count;
    }

    function getRestaurantDropCount(
        uint256 restaurantId
    ) public view returns (uint256) {
        return restaurantDropCount[restaurantId];
    }
}
