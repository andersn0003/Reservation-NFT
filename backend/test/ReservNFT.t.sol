// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/ReservNFT.sol";
import "../src/RestaurantManager.sol";

contract ReservNFTTest is Test {
    ReservNFT reservNFT;
    RestaurantManager restaurantManager;

    function setUp() public {
        restaurantManager = new RestaurantManager();
        reservNFT = new ReservNFT();

        // Set up the addresses after deploying both contracts

        restaurantManager.setReservNFTAddress(address(reservNFT));
        reservNFT.setRestaurantManagerAddress(address(restaurantManager));

        // Register a restaurant
        restaurantManager.registerRestaurant(
            "Test Restaurant",
            "123 Main St, New York, NY 10001"
        );
        uint64 startDate = 1672560000; // January 1, 2023, 8:00 AM UTC
        uint64 endDate = 1704060000; // December 31, 2023 10:00 PM UTC
        uint32 dailyStartTime = 28800; // 8:00 am in seconds
        uint32 dailyEndTime = 79200; // 10:00 pm in seconds
        uint32 windowDuration = 3600; // hourly windows in seconds
        uint16 reservationsPerWindow = 10;

        restaurantManager.createDrop(
            0,
            0.01 ether,
            startDate,
            endDate,
            dailyStartTime,
            dailyEndTime,
            windowDuration,
            reservationsPerWindow
        );
    }

    fallback() external payable {}

    function _createReservNFT(
        uint256 dropId,
        uint256 reservationTimestamp,
        uint256 value
    ) internal returns (uint256) {
        return
            reservNFT.createReservNFT{value: value}(
                dropId,
                reservationTimestamp
            );
    }

    function test_createReservNFT() public payable {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC

        uint256 tokenId = reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );

        ReservNFT.Reservation memory reservation = reservNFT
            .getReservationDetails(tokenId);

        assertEq(reservation.dropId, dropId);
        assertEq(reservation.restaurantId, 0);
        assertEq(reservation.reservationTimestamp, reservationTimestamp);
    }

    function testRevertWhen_createReservNFT_insufficientPayment() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        // Attempt to mint with insufficient payment
        vm.expectRevert(ReservNFT__InsufficientPayment.selector);
        reservNFT.createReservNFT{value: 0.005 ether}(
            dropId,
            reservationTimestamp
        );
    }

    function testRevertWhen_createReservNFT_inactiveDrop() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        // Deactivate the drop
        restaurantManager.setDropIsActive(dropId, false);
        // Attempt to mint from an inactive drop
        vm.expectRevert(ReservNFT__InactiveDrop.selector);
        reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );
    }

    function test_RevertWhen_createReservNFT_MoreThanUniqueNFTsForWindow()
        public
        payable
    {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        // Mint 10 NFTs for the given window
        for (uint8 i = 0; i < 10; i++) {
            reservNFT.createReservNFT{value: 0.01 ether}(
                dropId,
                reservationTimestamp
            );
        }

        // Attempt to mint an 11th NFT for the same window
        vm.expectRevert(ReservNFT__ExceedReservationsLimit.selector);
        reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );
    }

    function testRevertWhen_withdrawRestaurantOwnerBalance_noBalance() public {
        // Attempt to withdraw when there is no balance available
        vm.expectRevert(ReservNFT__NoBalanceAvailable.selector);
        reservNFT.withdrawRestaurantOwnerBalance();
    }

    function test_getReservationDetails() public payable {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        uint256 tokenId = reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );

        // Retrieve reservation details
        ReservNFT.Reservation memory reservation = reservNFT
            .getReservationDetails(tokenId);

        // Verify reservation details
        assertEq(reservation.dropId, dropId);
        assertEq(reservation.restaurantId, 0);
        assertEq(reservation.reservationTimestamp, reservationTimestamp);
    }

    function test_createReservNFT_withOverpayment() public payable {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        uint256 initialBalance = address(this).balance;

        // Mint with overpayment
        uint256 tokenId = reservNFT.createReservNFT{value: 0.02 ether}(
            dropId,
            reservationTimestamp
        );

        // Verify that the refund was received
        assertEq(address(this).balance, initialBalance - 0.01 ether); // Subtract the mint price from the initial balance

        // Retrieve reservation details
        ReservNFT.Reservation memory reservation = reservNFT
            .getReservationDetails(tokenId);

        // Verify reservation details
        assertEq(reservation.dropId, dropId);
        assertEq(reservation.restaurantId, 0);
        assertEq(reservation.reservationTimestamp, reservationTimestamp);
    }

    function test_tokenURI() public payable {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        uint256 tokenId = reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );

        // Retrieve drop details from RestaurantManager contract

        IRestaurantManager.Drop memory drop = IRestaurantManager(
            address(restaurantManager)
        ).getDrop(dropId);

        // Define the imageURI based on your desired image
        string
            memory imageURI = "https://cdn.onlinewebfonts.com/svg/img_481205.png";

        // Generate expected metadata JSON
        string memory expectedTokenURI = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"Reservation NFT", "description":"Restaurant reservation NFT", "attributes":[{"trait_type":"restaurantId","value":',
                            Strings.toString(drop.restaurantId),
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

        // Retrieve tokenURI for the minted NFT
        string memory actualTokenURI = reservNFT.tokenURI(tokenId);

        // Verify tokenURI
        assertEq(actualTokenURI, expectedTokenURI);
    }

    function testRevertWhen_createReservNFT_outsideDropWindow() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1641848400; // Jan 10 2022 21:00:00
        // Attempt to mint outside the drop window
        vm.expectRevert(ReservNFT__OutsideDropWindow.selector);
        reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );
    }

    function testRevertWhen_createReservNFT_outsideDailyWindow() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1672556400; // January 1, 2023, 7:00 AM UTC
        // Attempt to mint outside the daily window
        vm.expectRevert(ReservNFT__OutsideDailyWindow.selector);
        reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );
    }

    function testRevertWhen_createReservNFT_invalidWindowDuration() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1672561800; // Jan 1, 2023, 8:30 AM UTC
        // Attempt to mint with an invalid window duration
        vm.expectRevert(ReservNFT__InvalidWindowDuration.selector);
        reservNFT.createReservNFT{value: 0.01 ether}(
            dropId,
            reservationTimestamp
        );
    }
}
