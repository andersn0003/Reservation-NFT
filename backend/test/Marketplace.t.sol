// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/ReservNFT.sol";
import "../src/RestaurantManager.sol";

contract MarketplaceTest is Test {
    Marketplace marketplace;
    ReservNFT reservNFT;
    RestaurantManager restaurantManager;

    function setUp() public {
        reservNFT = new ReservNFT();
        restaurantManager = new RestaurantManager();

        marketplace = new Marketplace();

        // Set up the addresses after deploying both contracts
        restaurantManager.setReservNFTAddress(address(reservNFT));
        reservNFT.setRestaurantManagerAddress(address(restaurantManager));
        marketplace.setReservNFTAddress(address(reservNFT));

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

    function test_listReservation() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        // Approve Marketplace to manage the token
        reservNFT.approve(address(marketplace), tokenId);

        // List the reservation
        uint256 price = 0.02 ether;
        marketplace.listReservation(tokenId, price);

        // Check listing data
        Marketplace.Listing memory listing = marketplace.getReservationListing(
            tokenId
        );
        assertEq(listing.seller, address(this));
        assertEq(listing.price, price);
    }

    function test_buyReservation() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC

        address alice = vm.addr(1);

        payable(alice).transfer(5 ether);

        vm.prank(alice);
        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        address bob = vm.addr(2); // Add a new address for the buyer
        payable(bob).transfer(5 ether);
        // Transfer the token to Alice

        // Approve Marketplace to manage the token
        vm.prank(alice);
        reservNFT.approve(address(marketplace), tokenId);

        // List the reservation
        uint256 price = 0.02 ether;
        vm.prank(alice); // Set the contract caller to Alice
        marketplace.listReservation(tokenId, price);

        // Purchase the reservation
        uint256 startBalance = alice.balance; //4.99 ether
        vm.prank(bob);
        marketplace.buyReservation{value: price}(tokenId); // alice gets 0.02 so 5.01 bob has 4.98

        // Withdraw the funds

        vm.prank(alice);
        marketplace.withdrawProceeds();

        uint256 endBalance = alice.balance;
        assertEq(endBalance, startBalance + price);

        // Check new owner
        address tokenOwner = reservNFT.ownerOf(tokenId);
        assertEq(tokenOwner, bob); // Check if the new owner is bob
    }

    function test_removeReservationListing() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        // Approve Marketplace to manage the token
        reservNFT.approve(address(marketplace), tokenId);

        // List the reservation
        uint256 price = 0.02 ether;
        marketplace.listReservation(tokenId, price);

        // Remove the reservation listing
        marketplace.cancelReservationListing(tokenId);

        // Check if the listing has been removed
        Marketplace.Listing memory listing = marketplace.getReservationListing(
            tokenId
        );
    }

    function testRevertWhen_listReservation_invalidPrice() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400;

        address alice = vm.addr(1);
        payable(alice).transfer(5 ether);
        vm.prank(alice);

        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        vm.prank(alice);

        reservNFT.approve(address(marketplace), tokenId);

        vm.expectRevert(Marketplace__PriceMustBeAboveZero.selector);
        vm.prank(alice);

        marketplace.listReservation(tokenId, 0);
    }

    function testRevertWhen_listReservation_notApproved() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400;
        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        vm.expectRevert(Marketplace__NotApprovedForMarketplace.selector);
        marketplace.listReservation(tokenId, 0.02 ether);
    }

    function testRevertWhen_buyReservation_insufficientFunds() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400;

        address alice = vm.addr(1);
        payable(alice).transfer(5 ether);
        vm.prank(alice);

        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        vm.prank(alice);
        reservNFT.approve(address(marketplace), tokenId);
        vm.prank(alice);
        marketplace.listReservation(tokenId, 0.02 ether);

        bytes memory expectedError = abi.encodeWithSignature(
            "Marketplace__PriceNotMet(uint256,uint256)",
            tokenId,
            0.02 ether
        );
        vm.expectRevert(expectedError);

        marketplace.buyReservation{value: 0.001 ether}(tokenId);
    }

    function testRevertWhen_cancelReservationListing_notOwner() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400;
        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        reservNFT.approve(address(marketplace), tokenId);
        marketplace.listReservation(tokenId, 0.02 ether);

        address notOwner = vm.addr(1);
        vm.prank(notOwner);
        vm.expectRevert(Marketplace__NotOwner.selector);
        marketplace.cancelReservationListing(tokenId);
    }

    function testRevertWhen_updateReservationListing_notOwner() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400;
        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        reservNFT.approve(address(marketplace), tokenId);
        marketplace.listReservation(tokenId, 0.02 ether);

        address notOwner = vm.addr(1);
        vm.prank(notOwner);
        vm.expectRevert(Marketplace__NotOwner.selector);
        marketplace.updateReservationListing(tokenId, 0.03 ether);
    }

    function testRevertWhen_withdrawProceeds_noProceeds() public {
        address addr = vm.addr(1);
        vm.prank(addr);

        vm.expectRevert(Marketplace__NoProceeds.selector);
        marketplace.withdrawProceeds();
    }

    function test_listCancelAndRelistReservation() public {
        uint256 dropId = 0;
        uint256 reservationTimestamp = 1673384400; // January 10, 2023 21:00:00 UTC
        uint256 tokenId = _createReservNFT(
            dropId,
            reservationTimestamp,
            0.01 ether
        );

        // Approve the marketplace to handle the NFT
        reservNFT.approve(address(marketplace), tokenId);

        uint256 price = 0.1 ether;
        marketplace.listReservation(tokenId, price);

        // Test if the listing was successful
        Marketplace.Listing memory listing = marketplace.getReservationListing(
            tokenId
        );
        assertEq(listing.seller, address(this));
        assertEq(listing.price, price);

        // Test canceling the reservation listing
        marketplace.cancelReservationListing(tokenId);

        // Test if the listing was removed
        listing = marketplace.getReservationListing(tokenId);
        assertEq(listing.price, 0);

        // Test relisting the reservation
        uint256 newPrice = 0.15 ether;
        marketplace.listReservation(tokenId, newPrice);

        // Test if the relisting was successful
        listing = marketplace.getReservationListing(tokenId);
        assertEq(listing.seller, address(this));
        assertEq(listing.price, newPrice);
    }
}
