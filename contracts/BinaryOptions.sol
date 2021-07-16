// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Oracle.sol";

//1 bid is equal to 1 DVD token
//User can take any number of bids using DVD token
//Payout proportion would be calculated based on the number of bids the user has placed
contract BinaryOptions is Ownable, Pausable, Oracle {
    using SafeMath for uint256;

    bool admin;

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

    mapping(uint256 => address) longMap;
    mapping(uint256 => address) shortMap;
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
        address _aggregator,
        string memory _pair
    ) {
        contractExpiryTime = _contractExpiryTime;
        strikePrice = _strikePrice;
        bidPeriodTime = _bidPeriod;
        aggregator = _aggregator;
        dvdToken = _dvdToken;
        emit contractDeployment(
            _strikePrice,
            _bidPeriod,
            _contractExpiryTime,
            _aggregator,
            _pair
        );
    }

    //all events
    event eventBid(address biddingAddress, uint256 amount);
    event eventAnnounceResult(string);
    event eventPriceFeed(uint256);
    event eventPaid(address payerAddress, uint256 amount);
    //strikeprice, bidperiod, expiry, assetpair
    event contractDeployment(
        uint256 strikePrice,
        uint256 bidPeriod,
        uint256 expiry,
        address oracleAggregatorAddress,
        string assetPair
    );

    function bidLong(address _address, uint256 _bids) public whenNotPaused {
        //if current time is lesser than the bidding time limit then allow voting
        require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
        // dvdToken.transferFrom(msg.sender, address(this), 1);
        require(_bids >= 1, "Place a minimum of 1 bid");
        dvdToken.transferFrom(_address, address(this), _bids);
        dvdBalance[_address] = _bids;
        longBid++;
        totalBids++;
        longMap[longBid] = _address;
        emit eventBid(_address, _bids);
    }

    function bidShort(address _address, uint256 _bids) public whenNotPaused {
        //if current time is lesser than the bidding time limit then allow voting
        require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
        // dvdToken.transferFrom(msg.sender, address(this), 1);
        require(_bids >= 1, "Place a minimum of 1 bid");
        dvdToken.transferFrom(_address, address(this), _bids);
        dvdBalance[_address] = _bids;
        shortBid++;
        totalBids++;
        shortMap[shortBid] = _address;
        emit eventBid(_address, _bids);
    }

    /**Invoke price feed oracle and get price. Compare strike price and with value from price feed.
    if current time is more than the end time specified during contract creation then allow announce result*/
    function announceResult() public onlyOwner whenNotPaused {
        require(
            block.timestamp >= contractExpiryTime || admin,
            "Option Not Expired"
        );
        currentPrice = uint256(getPrice(aggregator));
        emit eventPriceFeed(currentPrice);
        if (currentPrice > strikePrice) {
            //long
            emit eventAnnounceResult("Positive Options Bid Win");
            // uint256 unit = totalBids / longBid;
            for (uint256 i = 0; i < longBid; i++) {
                address winner = longMap[i];
                // approve dvdtoken withdrawals based on number of tickets
                dvdToken.approve(winner, dvdBalance[winner]);
            }
        } else {
            //short
            emit eventAnnounceResult("Negative Options Bid Win");
            for (uint256 i = 0; i < shortBid; i++) {
                address winner = shortMap[i];
                // approve dvdtoken withdrawals based on number of tickets
                dvdToken.approve(winner, dvdBalance[winner]);
            }
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
        return dvdToken.balanceOf(_address);
    }

    function getContractDVDBalance() external view returns (uint256) {
        return dvdToken.balanceOf(address(this));
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function transferDVD(address _from, uint256 _amount) external {
        dvdToken.transferFrom(_from, address(this), _amount);
    }

    function setPause(bool pause) public onlyOwner {
        if (pause) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setAdmin(bool value) public onlyOwner {
        admin = value;
    }

    function isPaused() external view returns (bool) {
        return paused();
    }

    receive() external payable {
        emit eventPaid(msg.sender, msg.value);
    }
}
