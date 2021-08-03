// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Oracle {
    AggregatorV3Interface internal priceFeed;

    // constructor() public {
    //     priceFeed = AggregatorV3Interface(
    //         0x9326BFA02ADD2366b30bacB125260Af641031331
    //     );
    // }

    function getPrice(address aggregator) public returns (uint256) {
        priceFeed = AggregatorV3Interface(aggregator);
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        require(timeStamp > 0, "Round not complete");
        uint8 decimals = priceFeed.decimals();
        return uint256(price) / uint256(10**decimals);
    }
}
