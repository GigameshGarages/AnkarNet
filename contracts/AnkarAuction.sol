// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721Upgradeable.sol";

contract AnkarAuction {
    struct Bidder {
        address payable addr;
        uint256 amount;
        uint256 bidAt;
    }

    struct Auction {
        uint256 tokenId;
        address payable seller;
        uint256 price;
        uint256 amount;
        bool finished;
        Bidder[] bidders;
    }

    address payable public recipientAddr;
    IERC721 public nftContract;

    uint256 numAuctions;
    Auction[] auctions;

    mapping(uint256 => uint256) tokenIdToAuctionId;

    uint256 public bidLockTime = 1 days;

    uint256 constant platformFee = 50;
    uint256 constant feePercentage = 1000;

    constructor(IERC721 _nftContract, address payable _recipientAddr) {
        nftContract = _nftContract;
        recipientAddr = _recipientAddr;
    }

    event AuctionCreated(
        uint256 _tokenId,
        address indexed _seller,
        uint256 _value
    );

    function createAuction(
        uint256 _tokenId,
        address payable _seller,
        uint256 _price
    ) public returns (uint256 auctionId) {
        auctionId = numAuctions++;
        tokenIdToAuctionId[_tokenId] = auctionId;
        auctions.push();
        Auction storage auction = auctions[auctionId];
        auction.tokenId = _tokenId;
        auction.seller = _seller;
        auction.price = _price;
        emit AuctionCreated(_tokenId, _seller, _price);
    }

    event AuctionBidden(
        uint256 _tokenId,
        address indexed _bidder,
        uint256 _amount
    );

    function bid(uint256 _tokenId) public payable {
        uint256 auctionId = tokenIdToAuctionId[_tokenId];
        Auction storage auction = auctions[auctionId];
        require(msg.value > auction.price);
        require(!auction.finished);
        auction.amount += msg.value;
        auction.price = msg.value;
        auction.bidders.push(
            Bidder(payable(msg.sender), msg.value, block.timestamp)
        );
        emit AuctionBidden(_tokenId, msg.sender, msg.value);
    }

    event AuctionFinished(uint256 _tokenId, address indexed _awarder);

    function finish(uint256 _tokenId) public {
        uint256 auctionId = tokenIdToAuctionId[_tokenId];
        Auction storage auction = auctions[auctionId];
        Bidder memory awarder = auction.bidders[auction.bidders.length - 1];
        for (uint256 i = 0; i < auction.bidders.length - 1; i++) {
            Bidder memory bidder = auction.bidders[i];
            bidder.addr.transfer(bidder.amount);
        }
        uint256 receipientAmount =
            (awarder.amount * platformFee) / feePercentage;
        uint256 sellerAmount = awarder.amount - platformFee;
        recipientAddr.transfer(receipientAmount);
        auction.seller.transfer(sellerAmount);
        nftContract.transferFrom(auction.seller, awarder.addr, _tokenId);
        auction.finished = true;
        emit AuctionFinished(_tokenId, awarder.addr);
    }
}
