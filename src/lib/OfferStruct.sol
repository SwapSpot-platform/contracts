// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

enum OfferType { Buy, Sell }
enum AssetType { ERC721, ERC1155 }

struct Offer {
    address trader;
    OfferType side;
    address[] collections;
    uint256[] tokenIds;
    address paymentToken;
    uint256 price;
    uint256 listingTime;
    uint256 expirationTime;
    uint256 matchingId;
}

struct Fee {
    uint128 listingFee;
    uint128 buyingFee;
}