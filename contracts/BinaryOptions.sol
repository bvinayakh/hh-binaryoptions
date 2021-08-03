// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Oracle.sol";
import "./Authorizable.sol";

//1 bid is equal to 1 DVD token
//User can take any number of bids using DVD token
//Payout proportion would be calculated based on the number of bids the user has placed
contract BinaryOptions is Ownable, Authorizable, Pausable, Oracle {
    using SafeMath for uint256;
    using SafeMath for int256;

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

    uint256 dvdDecimalAdjust = 1 * (10**13);

    string pair;

    mapping(uint256 => address) longMap;
    mapping(uint256 => address) shortMap;
    mapping(address => uint256) userShortMap;
    mapping(address => uint256) userLongMap;
    mapping(address => uint256) dvdBalance;
    mapping(address => uint256) payout;

    //oracle price feed aggregator address
    address aggregator;

    //store investor and invested dvd token count
    struct investor {
        address investorAddress;
        uint256 amount;
        bool claimed;
    }

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
        pair = _pair;
        emit Deployment(
            _strikePrice,
            _bidPeriod,
            _contractExpiryTime,
            _aggregator,
            _pair
        );
    }

    //all events
    event AnnounceResult(string winner, uint256 strike, uint256 actual);
    event Winner(address winnerAddress, uint256 amount);
    //strikeprice, bidperiod, expiry, assetpair
    event Deployment(
        uint256 strikePrice,
        uint256 bidPeriod,
        uint256 expiry,
        address oracleAggregatorAddress,
        string assetPair
    );

    function bidLong(uint256 _bids) public whenNotPaused {
        //if current time is lesser than the bidding time limit then allow voting
        require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
        require(_bids >= 1, "Place a minimum of 1 bid (1 DVD Token)");
        address senderAddress = msg.sender;
        bool success = dvdToken.transferFrom(
            senderAddress,
            address(this),
            _bids * dvdDecimalAdjust
        );
        require(success, "DVD Token Transfer is not successful");
        dvdBalance[senderAddress] = dvdBalance[senderAddress] + _bids;
        longBid++;
        totalBids++;
        longMap[longBid] = senderAddress;
        userLongMap[senderAddress] = userLongMap[senderAddress] + 1;
    }

    function bidShort(uint256 _bids) public whenNotPaused {
        //if current time is lesser than the bidding time limit then allow voting
        require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
        require(_bids >= 1, "Place a minimum of 1 bid (1 DVD Token)");
        address senderAddress = msg.sender;
        bool success = dvdToken.transferFrom(
            senderAddress,
            address(this),
            _bids * dvdDecimalAdjust
        );
        require(success, "DVD Token Transfer is not successful");
        dvdBalance[senderAddress] = dvdBalance[senderAddress] + _bids;
        shortBid++;
        totalBids++;
        shortMap[shortBid] = senderAddress;
        userShortMap[senderAddress] = userShortMap[senderAddress] + 1;
    }

    /**Invoke price feed oracle and get price. Compare strike price and with value from price feed.
    if current time is more than the end time specified during contract creation then allow announce result*/
    function announceResult() public onlyOwner whenNotPaused {
        require(
            block.timestamp >= contractExpiryTime || admin,
            "Option Not Expired"
        );
        currentPrice = uint256(getPrice(aggregator));
        if (currentPrice > strikePrice) {
            //long
            for (uint256 i = 1; i <= longBid; i++) {
                address winner = longMap[i];
                // approve dvdtoken withdrawals based on number of tickets
                emit AnnounceResult("long", strikePrice, currentPrice);
                approveWithdrawal(winner, dvdBalance[winner]);
                payout[winner] = dvdBalance[winner];
                emit Winner(winner, dvdBalance[winner]);
            }
        } else if (currentPrice < strikePrice) {
            //short
            for (uint256 i = 1; i <= shortBid; i++) {
                address winner = shortMap[i];
                // approve dvdtoken withdrawals based on number of tickets
                emit AnnounceResult("short", strikePrice, currentPrice);
                approveWithdrawal(winner, dvdBalance[winner]);
                payout[winner] = dvdBalance[winner];
                emit Winner(winner, dvdBalance[winner]);
            }
        }
    }

    function claim() public {
        address sender = msg.sender;
        require(payout[sender] > 0, "Unauthorized Access");
        dvdToken.transfer(msg.sender, payout[sender] * (10**13));
        payout[sender] = 0;
    }

    //internal functions
    function approveWithdrawal(address _winner, uint256 _amount) internal {
        dvdToken.approve(_winner, _amount * (10**13));
    }

    //owner only functions
    function getOracleAddress() external view onlyOwner returns (address) {
        return aggregator;
    }

    function getContractBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function getContractDVDBalance() external view onlyOwner returns (uint256) {
        return dvdToken.balanceOf(address(this));
    }

    function setPause(bool pause) public onlyOwner {
        if (pause) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setAdmin(bool value) public onlyAuthorized {
        admin = value;
    }

    function isPaused() external view onlyOwner returns (bool) {
        return paused();
    }

    function isAdminEnabled() external view onlyOwner returns (bool) {
        return admin;
    }

    function updateAssetPairPrice() external onlyOwner {
        currentPrice = uint256(getPrice(aggregator));
    }

    //public open to all functions
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

    function getOraclePrice() external view returns (uint256) {
        return currentPrice;
    }

    function getBidPeriodLimit() external view returns (uint256) {
        return bidPeriodTime;
    }

    function getPriceAtExpiry() external view returns (uint256) {
        return currentPrice;
    }

    function getDVDBalance() external view returns (uint256) {
        return dvdToken.balanceOf(msg.sender);
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function getPair() external view returns (string memory) {
        return pair;
    }

    function getContract() external view returns (address) {
        return address(this);
    }

    function getUserBids() external view returns (uint256) {
        return dvdBalance[msg.sender];
    }

    function getUserShorts() external view returns (uint256) {
        return userShortMap[msg.sender];
    }

    function getUserLongs() external view returns (uint256) {
        return userLongMap[msg.sender];
    }
}
