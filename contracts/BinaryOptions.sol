// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Oracle.sol";
import "./Authorizable.sol";
import "./Biddable.sol";

//1 bid is equal to 1 USDx token
//User can take any number of bids using USDx token
//Payout proportion would be calculated based on the number of bids the user has placed
contract BinaryOptions is Ownable, Authorizable, Pausable, Biddable, Oracle {
  using SafeMath for uint256;
  using SafeMath for int256;

  bool private admin;
  bool private expiry;

  //fees 1%
  uint256 fees = 100;
  //option strike price at contract expiry
  uint256 strikePrice;
  //will determine when this contract will expire
  uint256 contractExpiryTime;
  //allowed bidding time period
  uint256 bidPeriodTime;
  //price at expiry
  uint256 currentPrice;
  //total bids
  uint256 totalBids;
  //total longs investment
  uint256 longsAmount;
  //total shorts investment
  uint256 shortsAmount;

  uint256 usdxDecimalAdjustment = 1 * (10**13);

  string pair;

  investor[] longs;
  investor[] shorts;

  //store investor and invested USDx token count
  struct investor {
    address investorAddress;
    uint256 amount;
    bool claimed;
  }

  mapping(address => uint256) userShortMap;
  mapping(address => uint256) userLongMap;
  mapping(address => uint256) usdxBalance;
  mapping(address => uint256) payout;
  mapping(address => uint256) investmentPercentageMap;

  mapping(address => investor) investorInformation;

  //oracle price feed aggregator address
  address aggregator;

  //allow USDx tokens only into the smart contract
  IERC20 private usdXToken;

  //options expiry timestamp in unix format, options strike price in uint256, bid price,
  //chainlink aggregator address
  constructor(
    IERC20 _usdXToken,
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
    usdXToken = _usdXToken;
    pair = _pair;
    allowBidding();
    emit Deployment(_usdXToken, _strikePrice, _bidPeriod, _contractExpiryTime, _aggregator, _pair);

    expiry = false;
  }

  //all events
  event AnnounceResult(string winner, uint256 strike, uint256 actual);
  event Payment(uint256 balance, uint256 participants);
  event Payout(address _address, uint256 _payout);
  event InvestmentPercentage(address _address, uint256 percentage);
  event Deployment(IERC20 usdXToken, uint256 strikePrice, uint256 bidPeriod, uint256 expiry, address oracleAggregatorAddress, string assetPair);

  function bidLong(uint256 _bids) public whenNotPaused whenBiddable {
    //if current time is lesser than the bidding time limit then allow voting
    require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
    require(_bids >= 1, "Place a minimum of 1 bid (1 USDx Token)");
    address senderAddress = msg.sender;
    bool success = usdXToken.transferFrom(senderAddress, address(this), _bids * usdxDecimalAdjustment);
    longsAmount = longsAmount + _bids * usdxDecimalAdjustment;
    require(success, "USDx Token Transfer is not successful");
    usdxBalance[senderAddress] = usdxBalance[senderAddress] + _bids;
    investor memory user;
    user.investorAddress = senderAddress;
    user.amount = user.amount.add(_bids * usdxDecimalAdjustment);
    user.claimed = false;
    longs.push(user);
    totalBids = totalBids + _bids;
    userLongMap[senderAddress] = userLongMap[senderAddress] + 1;
  }

  function bidShort(uint256 _bids) public whenNotPaused whenBiddable {
    //if current time is lesser than the bidding time limit then allow voting
    require(block.timestamp < bidPeriodTime, "Bidding Period has ended");
    require(_bids >= 1, "Place a minimum of 1 bid (1 USDx Token)");
    address senderAddress = msg.sender;
    bool success = usdXToken.transferFrom(senderAddress, address(this), _bids * usdxDecimalAdjustment);
    shortsAmount = shortsAmount + _bids * usdxDecimalAdjustment;
    require(success, "USDx Token Transfer is not successful");
    usdxBalance[senderAddress] = usdxBalance[senderAddress] + _bids;
    investor memory user;
    user.investorAddress = senderAddress;
    user.amount = user.amount.add(_bids * usdxDecimalAdjustment);
    user.claimed = false;
    shorts.push(user);
    totalBids = totalBids + _bids;
    userShortMap[senderAddress] = userShortMap[senderAddress] + 1;
  }

  /**Invoke price feed oracle and get price. Compare strike price and with value from price feed.
    if current time is more than the end time specified during contract creation then allow announce result*/
  function announceResult() public onlyAuthorized whenNotPaused {
    require(block.timestamp >= contractExpiryTime || admin, "Option Not Expired");
    currentPrice = uint256(getPrice(aggregator));
    if (currentPrice >= strikePrice) {
      //long
      emit AnnounceResult("long", strikePrice, currentPrice);
      for (uint256 i = 0; i < longs.length; i++) {
        investor memory user = longs[i];
        uint256 payment = user.amount.mul(usdXToken.balanceOf(address(this))).div(longsAmount);

        emit Payout(user.investorAddress, usdXToken.balanceOf(address(this)));

        emit Payout(user.investorAddress, longsAmount);
        emit Payout(user.investorAddress, payment);
        payout[user.investorAddress] = SafeMath.sub(payment, getPayoutFees(payment));
        emit Payout(user.investorAddress, payout[user.investorAddress]);
        require(approveWithdrawal(user.investorAddress, payout[user.investorAddress]), "Token Approval Failed");
      }
    } else if (currentPrice < strikePrice) {
      //short
      emit AnnounceResult("short", strikePrice, currentPrice);
      for (uint256 i = 0; i < shorts.length; i++) {
        investor memory user = shorts[i];
        uint256 payment = user.amount.mul(usdXToken.balanceOf(address(this))).div(shortsAmount);

        emit Payout(user.investorAddress, usdXToken.balanceOf(address(this)));
        emit Payout(user.investorAddress, shortsAmount);
        emit Payout(user.investorAddress, payment);
        payout[user.investorAddress] = SafeMath.sub(payment, getPayoutFees(payment));
        emit Payout(user.investorAddress, payout[user.investorAddress]);
        require(approveWithdrawal(user.investorAddress, payout[user.investorAddress]), "Token Approval Failed");
      }
    }
    //disable bidding once result is announced
    disallowBidding();
    expiry = true;
  }

  function claim() public whenNotPaused {
    address sender = msg.sender;
    require(payout[sender] > 0, "Unauthorized Access");
    usdXToken.transfer(msg.sender, payout[sender]);
    payout[sender] = 0;
  }

  function getPayoutFees(uint256 amount) internal view returns (uint256) {
    return SafeMath.div(SafeMath.mul(amount, fees), 10000);
  }

  function getPayout(uint256 _investmentPercentage) internal view whenNotPaused returns (uint256) {
    uint256 usdxAmount = usdXToken.balanceOf(address(this)) / (10**13);
    return SafeMath.mul(SafeMath.div(_investmentPercentage, 100), usdxAmount);
  }

  //internal functions
  function approveWithdrawal(address _winner, uint256 _amount) internal whenNotPaused returns (bool) {
    return usdXToken.approve(_winner, _amount);
  }

  //owner only functions
  function getOracleAddress() external view onlyAuthorized returns (address) {
    return aggregator;
  }

  function getInvestmentPercentage(address _address) external view onlyAuthorized returns (uint256) {
    return investmentPercentageMap[_address];
  }

  function getContractBalance() external view onlyAuthorized returns (uint256) {
    return address(this).balance;
  }

  function getContractusdxBalance() external view onlyAuthorized whenNotPaused returns (uint256) {
    //return value in decimals
    return SafeMath.div(usdXToken.balanceOf(address(this)), 10**13);
  }

  function setPause(bool pause) public onlyAuthorized {
    if (pause) {
      _pause();
    } else {
      _unpause();
    }
  }

  function setAdmin(bool value) public onlyAuthorized whenNotPaused {
    admin = value;
  }

  function isPaused() external view onlyAuthorized returns (bool) {
    return paused();
  }

  function isWinner(address _address) external view returns (bool) {
    if (payout[_address] > 0) return true;
    else return false;
  }

  function isAdminEnabled() external view onlyAuthorized whenNotPaused returns (bool) {
    return admin;
  }

  function updateAssetPairPrice() external onlyAuthorized whenNotPaused {
    currentPrice = uint256(getPrice(aggregator));
  }

  //public open to all functions
  function getLongs() external view whenNotPaused returns (uint256) {
    return longs.length;
  }

  function getShorts() external view whenNotPaused returns (uint256) {
    return shorts.length;
  }

  function getTotal() external view whenNotPaused returns (uint256) {
    return totalBids;
  }

  function getContractExpiry() external view whenNotPaused returns (uint256) {
    return contractExpiryTime;
  }

  function getStrikePrice() external view whenNotPaused returns (uint256) {
    return strikePrice;
  }

  function getOraclePrice() external view whenNotPaused returns (uint256) {
    return currentPrice;
  }

  function getBidPeriodLimit() external view whenNotPaused returns (uint256) {
    return bidPeriodTime;
  }

  function getPriceAtExpiry() external view whenNotPaused returns (uint256) {
    return currentPrice;
  }

  function getusdxBalance() external view whenNotPaused returns (uint256) {
    return usdXToken.balanceOf(msg.sender) * (10**13);
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

  // function getUserBids() external view whenNotPaused returns (uint256) {
  //     return usdxBalance[msg.sender];
  // }

  function getUserShorts() external view whenNotPaused returns (uint256) {
    return userShortMap[msg.sender];
  }

  function getUserLongs() external view whenNotPaused returns (uint256) {
    return userLongMap[msg.sender];
  }

  function hasContractExpire() external view whenNotPaused returns (bool) {
    return expiry;
  }

  function withdrawUSDx() external whenNotPaused onlyAuthorized {
    usdXToken.transfer(msg.sender, usdXToken.balanceOf(address(this)));
  }
}
