// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Auction {
    //VARIABLES
    uint256 public minimumBid;
    address[] public addressIndices;
    uint256 public previousRoundUsersCount; //To count the number of active users from the previous round (also used in the first round)

    uint256 public currentRoundUsersCount;
    uint256 roundNumber = 1;

    // Arrays to store both addresses and value of bids
    address[] addresses;
    address[] withdrawnUsers;
    uint256[] bidValues;

    struct Bid {
        bytes32 blindedBid;
        uint256 deposit;
    }

    address payable public owner;
    address public auctioneer;

    uint256 biddingEnd;
    uint256 revealEnd;

    bool public ended;
    bool public cancelled;
    bool ownerHasWithdrawn;

    mapping(address => uint256) public previousBids;
    mapping(address => uint256) currentRoundBid; // to store the incremental bid passed in the current round

    mapping(address => Bid[]) public bids;

    mapping(address => uint256) pendingReturns;

    address public highestBidder;
    uint256 public highestBid = 0;
    // uint256 public highestBindingBid; // equal to second highest bid? Not needed as highest bidder isnt allowed to withdraw

    // MODIFIERS

    modifier onlyBefore(uint256 _time) {
        require(block.timestamp < _time);
        _;
    }

    modifier onlyAfter(uint256 _time) {
        require(block.timestamp > _time);
        _;
    }

    modifier onlyAuctioneer() {
        require(msg.sender == auctioneer);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyNotOwner() {
        require(msg.sender != owner);
        _;
    }

    modifier onlyNotCancelled() {
        require(!cancelled);
        _;
    }

    modifier onlyNotHighestBidder() {
        require(msg.sender != highestBidder);
        _;
    }

    // EVENTS
    event roundEnded(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    //FUNCTIONS

    constructor(
        uint256 _biddingTime,
        uint256 _revealTime,
        address payable _owner,
        uint256 _minimumBid
    ) {
        owner = _owner;
        minimumBid = _minimumBid;
        biddingEnd = block.timestamp + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }

    function generateBlindedBidBytes32(uint256 value)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(value, msg.sender)); // taking the user address as the cryptographic salt
        // THIS FUNCTION IS COMPLETE
    }

    function bid(bytes32 _blindedBid) public payable onlyBefore(biddingEnd) {
        bids[msg.sender].push(
            Bid({blindedBid: _blindedBid, deposit: msg.value})
        );
    }

    function reveal() public onlyAfter(biddingEnd) onlyBefore(revealEnd) {
        // THIS FUNCTION IS INCOMPLETE
        uint256 length = bids[msg.sender].length;
        require(length == roundNumber);

        uint256 totalBidValue;
        Bid storage bidToCheck = bids[msg.sender][length - 1];
        uint256 value = require(
            bidToCheck.blindedBid ==
                keccak256(abi.encodePacked(value, msg.sender))
        );
        for (uint256 i = 0; i < length; i++) {
            Bid storage roundBid = bids[msg.sender][i];
            totalBidValue += roundBid.deposit;
        }
        pendingReturns[msg.sender] = totalBidValue;
    }

    function placeBid(address bidder, uint256 value)
        internal
        onlyNotCancelled
        onlyNotOwner
        returns (bool success)
    {
        //  WORK ON THIS FUNCTION - IT IS INCOMPLETE

        uint256 pastBids = pendingReturns[bidder]; //pendingReturns[bidder] contains the value of the past bids made by the user
        uint256 totalBid = pastBids + value;
        if (totalBid <= minimumBid) {
            return false;
        }
        if (totalBid > minimumBid) {
            pendingReturns[bidder] = totalBid;
            if (totalBid > highestBid) {
                highestBid = totalBid;
                highestBidder = bidder;
            }
            return true;
        }

        // THIS FUNCTION IS INCOMPLETE
    }

    function firstRoundEnd()
        public
        onlyAfter(revealEnd)
        onlyAuctioneer
        returns (uint256 _minimumBid)
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (previousBids[addresses[i]] > highestBid) {
                highestBid = previousBids[addresses[i]];
                highestBidder = addresses[i];
            }
        }
        minimumBid = highestBid; // set the minimum bid(for the next round) equal to the highest bid of the current round
        return minimumBid;
    }

    function roundEnd() public onlyAfter(revealEnd) onlyAuctioneer {
        // address[] storage withdrawnUsers;
        roundNumber++;
        for (uint256 i = 0; i < addresses.length; i++) {
            currentRoundBid[addresses[i]] += previousBids[addresses[i]];
            if (currentRoundBid[addresses[i]] == previousBids[addresses[i]]) {
                withdrawnUsers.push(addresses[i]);
            }
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            for (uint256 j = 0; j < withdrawnUsers.length; j++) {
                if (addresses[i] == withdrawnUsers[j]) {
                    delete addresses[i]; // this creates empty elements at the deleted places in the array -> work on shifting
                }
            }
        }

        // is called only after the bid reveal process for that round is over
        minimumBid = highestBid; //the minimum bid for the next round is equal to the highest bid of the just concluded round
        // find the number of active users - the no. of users who participated in the just concluded round

        // THIS FUNCTION IS INCOMPLETE
    }

    function withdraw() public onlyNotHighestBidder returns (bool success) {
        // mention when does it take place wrt the auction rounds
        address withdrawalAccount;
        uint256 withdrawalAmount;

        withdrawalAccount = msg.sender;
        withdrawalAmount = pendingReturns[withdrawalAccount];
        if (withdrawalAmount > 0) {
            pendingReturns[withdrawalAccount] = 0;
            payable(withdrawalAccount).transfer(withdrawalAmount);
            return true;
        } else {
            return false;
        }
    }

    function cancelAuction() public onlyNotCancelled onlyAuctioneer {
        cancelled = true;
    }
}

/*
    function roundOneBid(bytes32 _blindedBid)
        public
        payable
        onlyBefore(biddingEnd)
    {
        previousRoundUsersCount++;
        bids[msg.sender].push(
            Bid({blindedBid: _blindedBid, deposit: msg.value})
        );
        previousBids[msg.sender] = msg.value;
        addresses.push(msg.sender);
        bidValues.push(msg.value);
        previousBids[msg.sender] = msg.value;
    }

    function futureRoundBid(bytes32 _blindedBid)
        public
        payable
        onlyBefore(biddingEnd)
    {
        currentRoundUsersCount++;
        bids[msg.sender].push(
            Bid({blindedBid: _blindedBid, deposit: msg.value})
        );
        currentRoundBid[msg.sender] = msg.value;
        /*
        if (currentRoundBid[msg.sender] == 0) {
            currentRoundUsersCount--;
            // find the address of that user in the addresses array, shift it to the last element in the array and pop it out (basically delete that address from the array)
            for (uint256 i = 0; i < addresses.length; i++) {
                if (addresses[i] == msg.sender) {
                    address temp;
                    temp = addresses[addresses.length - 1];
                    addresses[addresses.length - 1] = addresses[i];
                    addresses[i] = temp;
                    delete addresses[addresses.length - 1];
                }
            }
        }
        
    }

    
}
*/
