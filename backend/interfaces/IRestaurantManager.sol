// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IRestaurantManager {
    struct Restaurant {
        address owner;
        string name;
        string businessAddress;
        bool isActive;
    }

    struct Drop {
        uint256 dropId;
        uint256 restaurantId;
        uint256 mintPrice;
        uint64 startDate;
        uint64 endDate;
        uint32 dailyStartTime;
        uint32 dailyEndTime;
        uint32 windowDuration;
        uint16 reservationsPerWindow;
        bool isActive;
    }

    event RestaurantRegistered(
        uint256 indexed restaurantId,
        address indexed owner,
        string name,
        string businessAddress
    );

    event RestaurantIsActive(uint256 indexed restaurantId, bool isActive);

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

    event DropIsActive(uint256 indexed dropId, bool isActive);

    function registerRestaurant(
        string calldata name,
        string calldata businessAddress
    ) external;

    function setRestaurantIsActive(uint256 restaurantId) external;

    function getRestaurant(
        uint256 restaurantId
    ) external view returns (Restaurant memory);

    function createDrop(
        uint256 restaurantId,
        uint256 mintPrice,
        uint64 startDate,
        uint64 endDate,
        uint32 dailyStartTime,
        uint32 dailyEndTime,
        uint32 windowDuration,
        uint16 reservationsPerWindow
    ) external;

    function setDropIsActive(uint256 dropId) external;

    function getDrop(uint256 dropId) external view returns (Drop memory);

    function getDropIDsByRestaurant(
        uint256 restaurantId
    ) external view returns (uint256[] memory);

    function getTimeSlotReservationCount(
        uint256 dropId,
        uint256 reservationTimestamp
    ) external view returns (uint256);

    function setTimeSlotReservationCount(
        uint256 dropId,
        uint256 reservationTimestamp,
        uint256 count
    ) external;
}
