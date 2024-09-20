// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnergyCredits.sol";
import "./P2PEnergyTrading.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract HTLCEnergyMarket is ReentrancyGuard {
    address public seller;
    uint256 public amount;
    bytes32 public hashLock;
    uint256 public timeLock;
    bool public refunded;

    EnergyCredits public energyCredits;
    
    // address of the contract allowed to interact with this contract
    address private p2pEnergyContract;

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
        timeLock = block.timestamp + _timeLock;
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
        require(block.timestamp <= timeLock, "Time lock expired");
        require(_price > bestPrice, "The price is lower than the current best offer");
        energyCredits.transferCredits(tx.origin, address(this),amount*_price);
        if (bestPrice != 0){
            energyCredits.transferCredits(address(this), bestBuyer ,amount*bestPrice); }
        bestBuyer = tx.origin;
        bestPrice = _price;

        emit OfferMade(tx.origin, _price);
    }

    // At the end of the timelock the secret is revealed (energy price decided by the seller) and the highest offer is evaluated
    // if the highest bid is not greater than or equal to the secret price, the funds are returned and the energy is not sold

    function energyHTLCSell(uint256 secretPrice) public onlyp2pEnergyContract nonReentrant returns(bool success){
        require(tx.origin == seller, "You are not the seller");
        require(block.timestamp > timeLock, "Time lock not yet expired");
        require(keccak256(abi.encodePacked(secretPrice)) == hashLock, "Invalid secret");
	
        if (bestPrice >= secretPrice){
            energyCredits.transferCredits(address(this), seller, amount * bestPrice);
            emit SaleFinalized(seller, amount * bestPrice);
            success = true;
            }
	
        else //refund
            if (bestPrice != 0){
                energyCredits.transferCredits(address(this), bestBuyer ,amount*bestPrice); 
                }

        bestBuyer = address(0);
        bestPrice = 0;
        return success;
    }

    // a buyer may decide to recover the funds (to avoid having them blocked)

    function refund() public onlyp2pEnergyContract nonReentrant {
        require(block.timestamp > timeLock, "Time lock not yet expired");
        require(tx.origin == bestBuyer, "nothing to refund");
        require(bestPrice > 0 , "nothing to refund");
        
        energyCredits.transferCredits(address(this), bestBuyer ,amount*bestPrice); 
        bestBuyer = address(0);
        bestPrice = 0;

        emit RefundIssued(bestBuyer, amount * bestPrice);
    }

}
