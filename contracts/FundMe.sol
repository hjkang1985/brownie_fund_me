// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract FundMe {
    // might be more expensive to make it a state variable rather than a local variable
    // AggregatorV3Interface priceFeed =
    //     AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e); // put in address from https://docs.chain.link/docs/ethereum-addresses/

    AggregatorV3Interface public priceFeed;

    mapping(address => uint256) public addressToAmountFunded; // when a mapping is created, all valid possible keys are created with the default null values. SOo can't really "loop" through a mapping
    address[] public funders;
    address payable public owner;

    constructor(address _priceFeed) public {
        // no need to make it public, because visibility of constructure is ignored; it's always called unless made an abstract
        priceFeed = AggregatorV3Interface(_priceFeed);
        owner = payable(msg.sender);
    }

    function fund() public payable {
        uint256 minimumUSD = 50; // in USD units
        require(
            getConversionRate(msg.value) >= (minimumUSD * 10**26),
            "You need to spend more ETH!"
        ); //using ETH -> USD conversion rate
        addressToAmountFunded[msg.sender] += msg.value; // what units are msg.value in? Wei? Gwei? Eth? Looks like in wei
        funders.push(msg.sender);
    }

    function getVersion() public view returns (uint256) {
        return priceFeed.version();
    }

    function getEthPrice() public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData(); //this returns in 10^8 decimal units, which is 10^8 of regular
        return uint256(answer);
    }

    // converts ETH (WEI) -> USD. Returns it in 10^(8 + 18) = 10^26 format
    function getConversionRate(uint256 _ethAmountWei)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getEthPrice(); // this is already in 10^8 format against 1 ETH
        return _ethAmountWei * ethPrice; // since we take wei and don't divide it, this adds an extra 10^18, making it 10^26 format of dollars
    }

    // return entrance fee in wei (ie. how many 10^-18 ETH we need)
    function getEntranceFee() public view returns (uint256) {
        // minimum USD
        uint256 minimumUSD = 55 * 10**8;
        uint256 price = getEthPrice(); // 10^8 units
        uint256 precision = 10**18;
        return (minimumUSD * precision) / price;
    }

    // only want the contract admin/owner
    modifier onlyOwner() {
        require(msg.sender == owner); // type conversion doesn't seem needed for the comparison
        _;
    }

    function withdraw() public payable onlyOwner {
        // this function itself probably doesn't need to be payable. Only the address has to be

        address payable contractCallerAddress = payable(msg.sender);
        contractCallerAddress.transfer(address(this).balance);

        for (uint256 i = 0; i < funders.length; i++) {
            address funder = funders[i];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0); // initializing the size of the array to 0? can't make aa dynamic array in memory function calls
    }
}
