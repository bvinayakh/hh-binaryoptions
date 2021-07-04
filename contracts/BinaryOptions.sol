// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Oracle.sol";

//1 bid is equal to 1 DVD token
//User can take any number of bids using DVD token
//Payout proportion would be calculated based on the number of bids the user has placed
contract BinaryOptions is Ownable, Pausable, Oracle {
    //total number of bids
    uint256 totalBids;
    //total number of short bids
    uint256 shortBid;
    //total number of long bids
    uint256 longBid;
    //option strike price at contract expiry
    uint256 strikePrice;
    //will determine when this contract will expire
    uint256 contractExpiryTime;
    //allowed bidding time period
    uint256 bidPeriodTime;
    //price at expiry
    uint256 currentPrice;

    mapping(address => uint256) longMap;
    mapping(address => uint256) shortMap;
    mapping(address => uint256) dvdBalance;

    //oracle price feed aggregator address
    address aggregator;

    //allow DVD tokens only into the smart contract
    IERC20 private dvdToken;

    //options expiry timestamp in unix format, options strike price in uint256, bid price,
    //chainlink aggregator address
    constructor(
        IERC20 _dvdToken,
        uint256 _contractExpiryTime,
        uint256 _strikePrice,
        uint256 _bidPeriod,
        address _aggregator
    ) {
        contractExpiryTime = _contractExpiryTime;
        strikePrice = _strikePrice;
        bidPeriodTime = _bidPeriod;
        aggregator = _aggregator;
        dvdToken = _dvdToken;
    }

    //all events
    event eventLongBid(string);
    event eventShortBid(string);
    event eventReceiveFunds(string, address, uint256);
    event eventAnnounceResult(string);
    event eventPriceFeed(uint256);

    function bidLong(uint256 bids) public payable whenNotPaused {
        //if current time is lesser than the bidding time limit then allow voting
        require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
        // dvdToken.transferFrom(msg.sender, address(this), 1);
        require(bids >= 1, "Place a minimum of 1 bid");
        totalBids++;
        // lets assume every vote is 1000 wei
        // longMap[participant] = bids;
        longMap[msg.sender] = bids;
        longBid++;
        emit eventReceiveFunds("bid long called", msg.sender, msg.value);
        emit eventLongBid("Long Bid Invoked");
    }

    function bidShort(uint256 bids) public payable whenNotPaused {
        //if current time is lesser than the bidding time limit then allow voting
        require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
        // dvdToken.transferFrom(msg.sender, address(this), 1);
        require(bids >= 1, "Place a minimum of 1 bid");
        totalBids++;
        // assume every vote is 1000 wei
        // shortMap[participant] = bids;
        shortMap[msg.sender] = bids;
        shortBid++;
        emit eventReceiveFunds("bid short called", msg.sender, msg.value);
        emit eventShortBid("Short Bid Invoked");
    }

    /**Invoke price feed oracle and get price. Compare strike price and with value from price feed.
    if current time is more than the end time specified during contract creation then allow announce result*/
    function announceResult() public onlyOwner whenNotPaused {
        require(block.timestamp >= contractExpiryTime, "Option Not Expired");
        currentPrice = uint256(getPrice(aggregator));
        emit eventPriceFeed(currentPrice);
        if (currentPrice > strikePrice) {
            //positive won
            // amountperwinner = address(this).balance/positiveCount;
            emit eventAnnounceResult("Positive Options Bid Win");
            // enable withdrawals based on number of tickets
        } else {
            //negative won
            // amountperwinner = address(this).balance/negativeCount;
            emit eventAnnounceResult("Negative Options Bid Win");
            // enable withdrawals based on number of tickets
        }
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getLongs() external view returns (uint256) {
        return longBid;
    }

    function getShorts() external view returns (uint256) {
        return shortBid;
    }

    function getTotal() external view returns (uint256) {
        return totalBids;
    }

    function getContractExpiry() external view returns (uint256) {
        return contractExpiryTime;
    }

    function getStrikePrice() external view returns (uint256) {
        return strikePrice;
    }

    function getBidPeriodLimit() external view returns (uint256) {
        return bidPeriodTime;
    }

    function getPriceAtExpiry() external view returns (uint256) {
        return currentPrice;
    }

    function getDVDBalance(address _address) external view returns (uint256) {
        return dvdBalance[_address];
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    receive() external payable {
        dvdBalance[msg.sender] = msg.value;
        emit eventReceiveFunds("receive fnction called", msg.sender, msg.value);
    }
}
