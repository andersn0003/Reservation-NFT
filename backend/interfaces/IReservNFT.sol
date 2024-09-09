// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IReservNFT {
    struct Reservation {
        uint256 restaurantId;
        uint256 dropId;
        uint256 reservationTimestamp; // Represents both date and time
    }

    function getReservationDetails(
        uint256 tokenId
    ) external view returns (Reservation memory);
}
