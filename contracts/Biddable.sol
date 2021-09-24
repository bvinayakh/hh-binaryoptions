// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Biddable is Ownable {
    bool biddable;

    modifier whenBiddable() {
        require(biddable, "Bidding Phase is Over");
        _;
    }

    function allowBidding() internal {
        biddable = true;
    }

    function disallowBidding() internal {
        biddable = false;
    }
}
