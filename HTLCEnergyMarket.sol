// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EnergyCredits.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HTLCEnergyMarket is ReentrancyGuard {
    address public immutable seller;
    uint256 public immutable amount;
    bytes32 public immutable hashLock;
    uint256 public immutable timeLock;
    bool public immutable refunded;

    EnergyCredits public immutable energyCredits;

    // address of the contract allowed to interact with this contract
    address private immutable p2pEnergyContract;

    // list of possible buyers
    address public bestBuyer;
    uint256 public bestPrice;

    constructor(
        uint256 _amount,
        bytes32 _hashLock,
        uint256 _timeLock,
        address _energyCredits
    ) {
        seller = tx.origin;
        amount = _amount;
        hashLock = _hashLock;
        timeLock = block.number + _timeLock;
        refunded = false;
        energyCredits = EnergyCredits(_energyCredits);
        p2pEnergyContract = msg.sender;
    }

    event OfferMade(address indexed buyer, uint256 price);
    event SaleFinalized(address indexed seller, uint256 amount);
    event RefundIssued(address indexed buyer, uint256 amount);

    modifier onlyp2pEnergyContract() {
        require(msg.sender == p2pEnergyContract, "Caller is not the P2PEnergyTrading contract, unautorized!");
        _;
    }

    function getBestBuyer() public view returns (address) {
        return bestBuyer;
    }

    function getBestPrice() public view returns (uint256) {
        return bestPrice;
    }

    // seller: hides the price of energy until the end of the timeLock
    // buyer: makes an offer to purchase the energy (participates in the auction), locking in his funds until his bid is exceeded
    
    function energyPurchaseOffer(uint256 _price) public onlyp2pEnergyContract nonReentrant{
    	require(block.number <= timeLock, "Time lock expired");
        require(_price > bestPrice, "The price is lower than the current best offer");
	
	// avoid reentrancy attacks by using temporary auxiliary variables 
	address previousBestBuyer = bestBuyer;
	uint256 previousBestPrice = bestPrice;
	bestBuyer = tx.origin;
        bestPrice = _price;

        if (bestPrice != 0){
            bool success = energyCredits.transferFrom(address(this), previousBestBuyer ,amount*previousBestPrice); 
       	    require(success, "tranfer failed");
	    }

        emit OfferMade(tx.origin, _price);
    }

    // At the end of the timelock the secret is revealed (energy price decided by the seller) and the highest offer is evaluated
    // if the highest bid is not greater than or equal to the secret price, the funds are returned and the energy is not sold

    function energyHTLCSell(uint256 secretPrice) public onlyp2pEnergyContract nonReentrant returns(bool success){
        require(tx.origin == seller, "You are not the seller");
        require(block.number > timeLock, "Time lock not yet expired");
        require(keccak256(abi.encodePacked(secretPrice)) == hashLock, "Invalid secret");

	// avoid reentrancy attacks by using temporary auxiliary variables 
	address previousBestBuyer = bestBuyer;
	uint256 previousBestPrice = bestPrice;
	bestBuyer = address(0);
        bestPrice = 0;
	
        if (bestPrice >= secretPrice){
            bool success = energyCredits.transferFrom(address(this), seller, amount * previousBestPrice);
	    require(success, "tranfer failed");
            emit SaleFinalized(seller, amount * previousBestPrice);
            }
	
        else //refund
            if (bestPrice != 0){
                bool success = energyCredits.transferFrom(address(this), previousBestBuyer ,amount*previousBestPrice); 
		require(success, "tranfer failed");
                }
    }

    // a buyer may decide to recover the funds (to avoid having them blocked)

    function refund() public onlyp2pEnergyContract nonReentrant {
        require(block.number > timeLock, "Time lock not yet expired");
        require(tx.origin == bestBuyer, "nothing to refund");
        require(bestPrice > 0 , "nothing to refund");

	// avoid reentrancy attacks by using temporary auxiliary variables 
	address previousBestBuyer = bestBuyer;
	uint256 previousBestPrice = bestPrice;
	bestBuyer = address(0);
        bestPrice = 0;
        
        bool success = energyCredits.transferFrom(address(this), previousBestBuyer ,amount*previousBestPrice); 
	require(success, "tranfer failed");

        emit RefundIssued(previousBestBuyer, amount * previousBestPrice);
    }

}

contract P2PEnergyTrading is ReentrancyGuard {

    address private immutable owner;

    struct User {
        address meterId;
        uint256 energyProduced;
        uint256 energyConsumed;
        bool isRenewableSource;
    }

    struct EnergyData {
        uint256 produced; 
        uint256 consumed; 
        bool isRenewable;
    }

    struct EnergyOffer {
        address seller;
        address htlcContract;
        bool isRenewable;
        uint256 amount;
    }

    mapping(address => User) public users;
    mapping(uint256 => EnergyOffer) public offers;
    uint256 public nextOfferId;

    // Smart meters and authorization keys
    mapping(address => bool) public authorizedMeters;
    mapping(address => bytes32) public authorizationKeyHashes; // Hashes of authorization keys

    EnergyCredits public immutable energyCreditsContract;

    event UserRegistered(address user, address meterId);
    event MeterAuthorized(address meterId);
    
    event EnergyDataUpdated(address indexed user, uint256 produced, uint256 consumed, bool isRenewable);
    event EnergyOffered(address indexed seller, uint256 amount, bytes32 hashlock, address htlcContract);
    event EnergyPurchased(address indexed buyer, address indexed seller, uint256 amount, uint256 price, bool isRenewable);
    event EnergyBought(uint256 offerId, address buyer, uint256 price);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor(address energyCreditsAddress) {
        owner = msg.sender;
        energyCreditsContract = EnergyCredits(energyCreditsAddress);
    }

    function authorizeMeter(address meterId, bytes32 authKeyHash) 
        public onlyOwner {
	
	require(meterId != address(0), "Invalid meter address");

        authorizedMeters[meterId] = true;
        authorizationKeyHashes[meterId] = authKeyHash;
        emit MeterAuthorized(meterId);
    }

    function registerUser(
        address meterId, 
        string memory authKey) 
        public {
        require(authorizedMeters[meterId], "Meter not authorized");
        require(authorizationKeyHashes[meterId] == keccak256(abi.encodePacked(authKey)), "Invalid authorization key");
	require(users[msg.sender].meterId == address(0), "User already registered");

        users[msg.sender] = User(meterId, 0, 0, false);
        emit UserRegistered(msg.sender, meterId);
    }

    function isUserRegistered(address user) public view returns (bool) {
        return users[user].meterId != address(0);
    }

    function updateEnergyData(
        address userAddress, 
        EnergyData memory data) 
        public {
        require(users[userAddress].meterId == msg.sender, "Meter ID not valid");

        (uint256 produced, uint256 consumed, bool isRenewable) = 
                    (data.produced, data.consumed, data.isRenewable);
        users[userAddress].energyProduced += produced;
        users[userAddress].energyConsumed += consumed;
        users[userAddress].isRenewableSource = isRenewable && users[userAddress].isRenewableSource  ;

        if (isRenewable) {
            uint256 credits = produced * 10; // 1 credit for each 1 W produced
            energyCreditsContract.issueCredits(userAddress, credits);
        }

        emit EnergyDataUpdated(userAddress, produced, consumed, isRenewable);
    }


    // an ‘object’ offer includes an HTLC contract that secretly sets the rules 
    // of sale and bases them on a simple auction
    function createOfferEnergy(
        uint256 amount, 
        bool isRenewable, 
        bytes32 hashLock, 
        uint256 timeLock
    ) public {
  
  /*
        This function will deploy a contract ‘EnergyOffer' contract. 
        The EnergyOffer contract implements an HTLC logic where the 
        hash hides the energy price.
        Time represents the duration of the offer.
  */
        require(users[msg.sender].energyProduced >= amount, "Not enough energy produced");

        HTLCEnergyMarket htlc = new HTLCEnergyMarket(
    	  	amount,
    		hashLock,
    		timeLock,
    		address(energyCreditsContract)
        );

        users[msg.sender].energyProduced -= amount;
        offers[nextOfferId++] = EnergyOffer(msg.sender, address(htlc), isRenewable, amount);

        emit EnergyOffered(msg.sender, amount, hashLock, address(htlc));
    }



    function buyEnergy(uint256 offerId, uint256 price) public nonReentrant {

        /*
        A bidder may make a bid by paying in Energy Credits 
        (providing the contractual authorisation to move the tokens). 
        */

        address addressOffer = offers[offerId].htlcContract;

        HTLCEnergyMarket htlcOffer = HTLCEnergyMarket(addressOffer);
        htlcOffer.energyPurchaseOffer(price);

	emit EnergyBought(offerId, msg.sender, price);
   }


    function sellEnergy(uint256 offerId, uint256 secretPrice) public nonReentrant {

         /* 
    	At the end of the duration, the creator of the offer reveals
        the energy price. Through the HTLC contract, the bid is won by the bidder 
        who has bid the highest amount and which is not lower than the revealed price.
        When this happens, the transfer of the energy takes place.        
        */

        require(msg.sender == offers[offerId].seller, "Only the seller can finalize the sale");

        address addressOffer = offers[offerId].htlcContract;
        HTLCEnergyMarket htlcOffer = HTLCEnergyMarket(addressOffer);
        bool result = htlcOffer.energyHTLCSell(secretPrice);
    
        if (result) {
            // Transfer energy to the highest bidder
            users[htlcOffer.bestBuyer()].energyProduced += offers[offerId].amount;        
            emit EnergyPurchased(htlcOffer.bestBuyer(), offers[offerId].seller, offers[offerId].amount, htlcOffer.bestPrice(), offers[offerId].isRenewable);
        }
        else {
            users[offers[offerId].seller].energyProduced += offers[offerId].amount;
        }       
    }

    function getKeccakString(string memory secret) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret));
    }

    function getKeccakNumber(uint secret) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret));
    }

}
