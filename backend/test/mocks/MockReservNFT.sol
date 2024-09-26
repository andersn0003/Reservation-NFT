// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../../interfaces/IReservNFT.sol";

error ReservNFT__Unauthorized();

contract MockReservNFT is ERC721, IReservNFT {
    address owner;
    address restaurantManagerAddress;

    constructor() ERC721("Mock ReservNFT", "MRNFT") {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ReservNFT__Unauthorized();
        }
        _;
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function getReservationDetails(
        uint256 tokenId
    ) external view override returns (IReservNFT.Reservation memory) {
        return
            IReservNFT.Reservation({
                dropId: 0,
                restaurantId: 0,
                reservationTimestamp: 1700000001
            });
    }

    function setRestaurantManagerAddress(
        address _restaurantManagerAddress
    ) public onlyOwner {
        restaurantManagerAddress = _restaurantManagerAddress;
    }
}
