// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RestaurantManager.sol";
import "../interfaces/IReservNFT.sol";
import "./mocks/MockReservNFT.sol";

contract RestaurantManagerTest is Test {
    RestaurantManager restaurantManager;
    MockReservNFT mockReservNFT;

    function setUp() public {
        restaurantManager = new RestaurantManager();
        mockReservNFT = new MockReservNFT();

        // Set up the addresses after deploying both contracts
        restaurantManager.setReservNFTAddress(address(mockReservNFT));
        mockReservNFT.setRestaurantManagerAddress(address(restaurantManager));
    }

    function registerSampleRestaurant() internal returns (uint256) {
        restaurantManager.registerRestaurant(
            "Hungry Hippos",
            "123 Main St, New York, NY 10001"
        );
    }

    function createSampleDrop()
        internal
        returns (
            uint64 startDate,
            uint64 endDate,
            uint32 dailyStartTime,
            uint32 dailyEndTime,
            uint32 windowDuration,
            uint16 reservationsPerWindow
        )
    {
        uint64 startDate = 1700000000;
        uint64 endDate = 1700003600;
        uint32 dailyStartTime = 28800; // 8:00 am in seconds
        uint32 dailyEndTime = 79200; // 10:00 pm in seconds
        uint32 windowDuration = 3600; // hourly windows in seconds
        uint16 reservationsPerWindow = 10;

        restaurantManager.createDrop(
            0,
            100,
            startDate,
            endDate,
            dailyStartTime,
            dailyEndTime,
            windowDuration,
            reservationsPerWindow
        );

        return (
            startDate,
            endDate,
            dailyStartTime,
            dailyEndTime,
            windowDuration,
            reservationsPerWindow
        );
    }

    function test_RegisterRestaurant() public {
        uint256 restaurantId = registerSampleRestaurant();

        RestaurantManager.Restaurant memory res = restaurantManager
            .getRestaurant(restaurantId);

        assertEq(
            res.name,
            "Hungry Hippos",
            "Restaurant name should be Hungry Hippos"
        );

        assertEq(
            res.businessAddress,
            "123 Main St, New York, NY 10001",
            "Restaurant location should be 123 Main St, New York, NY 10001"
        );

        assertEq(
            res.owner,
            address(this),
            "Restaurant owner should be the address of the test contract"
        );
    }

    function test_SetRestaurantIsActive() public {
        uint256 restaurantId = registerSampleRestaurant();

        restaurantManager.setRestaurantIsActive(0, false);

        RestaurantManager.Restaurant memory res = restaurantManager
            .getRestaurant(restaurantId);

        assertEq(res.isActive, false, "Restaurant should be inactive");
    }

    function test_RevertWhen_SetIsActiveByNonOwner() public {
        uint256 restaurantId = registerSampleRestaurant();

        vm.prank(address(0x1234));

        vm.expectRevert(RestaurantManager__Unauthorized.selector);

        restaurantManager.setRestaurantIsActive(restaurantId, false);
    }

    function test_CreateDropWithHourlyWindows() public {
        uint256 restaurantId = registerSampleRestaurant();
        (
            uint64 startDate,
            uint64 endDate,
            uint32 dailyStartTime,
            uint32 dailyEndTime,
            uint32 windowDuration,
            uint16 reservationsPerWindow
        ) = createSampleDrop();

        RestaurantManager.Drop memory drop = restaurantManager.getDrop(
            restaurantId
        );

        assertEq(drop.startDate, startDate, "Start date should match");
        assertEq(drop.endDate, endDate, "End date should match");
        assertEq(
            drop.dailyStartTime,
            dailyStartTime,
            "Daily start time should match"
        );
        assertEq(
            drop.dailyEndTime,
            dailyEndTime,
            "Daily end time should match"
        );
        assertEq(
            drop.windowDuration,
            windowDuration,
            "Window duration should match"
        );
        assertEq(
            drop.reservationsPerWindow,
            reservationsPerWindow,
            "Reservations per window should match"
        );
    }

    function test_RevertWhen_CreateDropByNonOwner() public {
        uint256 restaurantId = registerSampleRestaurant();

        vm.prank(address(0x1234));
        vm.expectRevert(RestaurantManager__Unauthorized.selector);

        (
            uint64 startDate,
            uint64 endDate,
            uint32 dailyStartTime,
            uint32 dailyEndTime,
            uint32 windowDuration,
            uint16 reservationsPerWindow
        ) = createSampleDrop();
    }

    function test_SetDropIsActive() public {
        uint256 restaurantId = registerSampleRestaurant();

        (
            uint64 startDate,
            uint64 endDate,
            uint32 dailyStartTime,
            uint32 dailyEndTime,
            uint32 windowDuration,
            uint16 reservationsPerWindow
        ) = createSampleDrop();

        restaurantManager.setDropIsActive(0, false);

        RestaurantManager.Drop memory drop = restaurantManager.getDrop(0);

        assertFalse(drop.isActive, "Drop should be inactive");
    }

    function test_RevertWhen_SetDropIsActiveByNonOwner() public {
        uint256 restaurantId = registerSampleRestaurant();

        (
            uint64 startDate,
            uint64 endDate,
            uint32 dailyStartTime,
            uint32 dailyEndTime,
            uint32 windowDuration,
            uint16 reservationsPerWindow
        ) = createSampleDrop();

        vm.prank(address(0x1234));
        vm.expectRevert(RestaurantManager__Unauthorized.selector);

        restaurantManager.setDropIsActive(0, false);
    }

    function test_GetRestaurantDropCount() public {
        uint256 restaurantId = registerSampleRestaurant();

        (
            uint64 startDate,
            uint64 endDate,
            uint32 dailyStartTime,
            uint32 dailyEndTime,
            uint32 windowDuration,
            uint16 reservationsPerWindow
        ) = createSampleDrop();
        uint256 dropCount = restaurantManager.getRestaurantDropCount(0);
        assertEq(
            dropCount,
            1,
            "There should be one drop associated with the restaurant"
        );
    }

    function test_GetDropIDsByRestaurant() public {
        uint256 restaurantId = registerSampleRestaurant();

        (
            uint64 startDate,
            uint64 endDate,
            uint32 dailyStartTime,
            uint32 dailyEndTime,
            uint32 windowDuration,
            uint16 reservationsPerWindow
        ) = createSampleDrop();

        uint256[] memory dropIDs = restaurantManager.getDropIDsByRestaurant(0);
        assertEq(
            dropIDs.length,
            1,
            "There should be one drop associated with the restaurant"
        );
        assertEq(dropIDs[0], 0, "The drop ID should be 0");
    }

    function test_RevertWhen_GetDropWithInvalidID() public {
        vm.expectRevert(RestaurantManager__DropDoesNotExist.selector);
        restaurantManager.getDrop(0);
    }

    function test_RevertWhen_GetRestaurantWithInvalidID() public {
        vm.expectRevert(RestaurantManager__RestaurantDoesNotExist.selector);
        restaurantManager.getRestaurant(0);
    }

    function test_RevertWhen_InvalidDropDates() public {
        uint256 restaurantId = registerSampleRestaurant();

        uint64 startDate = 1700000000;
        uint64 endDate = 1700000000;
        uint32 dailyStartTime = 28800; // 8:00 am in seconds
        uint32 dailyEndTime = 79200; // 10:00 pm in seconds
        uint32 windowDuration = 3600; // hourly windows in seconds
        uint16 reservationsPerWindow = 10;

        vm.expectRevert(RestaurantManager__InvalidDropDates.selector);

        restaurantManager.createDrop(
            0,
            100,
            startDate,
            endDate,
            dailyStartTime,
            dailyEndTime,
            windowDuration,
            reservationsPerWindow
        );
    }
}
