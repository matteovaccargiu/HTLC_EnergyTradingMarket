// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnergyCredits.sol";
import "./HTLCEnergyMarket.sol";


contract P2PEnergyTrading {
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

    EnergyCredits public energyCreditsContract;

    event UserRegistered(address user, address meterId);
    event MeterAuthorized(address meterId);
    
    event EnergyDataUpdated(address indexed user, uint256 produced, uint256 consumed, bool isRenewable);
    event EnergyOffered(address indexed seller, uint256 amount, bytes32 hashlock, address htlcContract);
    event EnergyPurchased(address indexed buyer, address indexed seller, uint256 amount, uint256 price, bool isRenewable);

    constructor(address energyCreditsAddress) {
        energyCreditsContract = EnergyCredits(energyCreditsAddress);
    }

    function authorizeMeter(address meterId, bytes32 authKeyHash) 
        public {
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

        users[msg.sender] = User(meterId, 0, 0, false);
        emit UserRegistered(msg.sender, meterId);
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
            address(energyCreditsContract),
            address(this)
        );

        users[msg.sender].energyProduced -= amount;
        offers[nextOfferId++] = EnergyOffer(msg.sender, address(htlc), isRenewable, amount);

        emit EnergyOffered(msg.sender, amount, hashLock, address(htlc));
    }



    function buyEnergy(uint256 offerId, uint256 price) public {

        /*
        A bidder may make a bid by paying in Energy Credits 
        (providing the contractual authorisation to move the tokens). 
        */

        address addressOffer = offers[offerId].htlcContract;

        HTLCEnergyMarket htlcOffer = HTLCEnergyMarket(addressOffer);
        htlcOffer.energyPurchaseOffer(price);

   }


    function sellEnergy(uint256 offerId, uint256 secretPrice) public {

         /* 
    	At the end of the duration, the creator of the offer reveals
        the energy price. Through the HTLC contract, the bid is won by the bidder 
        who has bid the highest amount and which is not lower than the revealed price.
        When this happens, the transfer of the energy takes place.        
        */
        address addressOffer = offers[offerId].htlcContract;
        HTLCEnergyMarket htlcOffer = HTLCEnergyMarket(addressOffer);
        bool result = htlcOffer.energyHTLCSell(secretPrice);
    
        if (result) {
            // Transfer energy to the highest bidder
            users[htlcOffer.bestBuyer()].energyProduced += offers[offerId].amount;
            //users[offers[offerId].seller].energyProduced -= offers[offerId].amount;
        
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