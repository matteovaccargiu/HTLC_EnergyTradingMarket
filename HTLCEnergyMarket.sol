// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnergyCredits.sol";
import "./P2PEnergyTrading.sol";

contract HTLCEnergyMarket {
    address public seller;
    uint256 public amount;
    bytes32 public hashLock;
    uint256 public timeLock;
    bool public refunded;

    EnergyCredits public energyCredits;
    P2PEnergyTrading public energyTrading;

    // list of possible buyers
    address public bestBuyer;
    uint256 public bestPrice;

    constructor(
        uint256 _amount,
        bytes32 _hashLock,
        uint256 _timeLock,
        address _energyCredits,
        address _energyTrading
    ) {
        seller = tx.origin;
        amount = _amount;
        hashLock = _hashLock;
        timeLock = block.timestamp + _timeLock;
        refunded = false;
        energyCredits = EnergyCredits(_energyCredits);
        energyTrading = P2PEnergyTrading(_energyTrading);
    }

    function getBestBuyer() public view returns (address) {
        return bestBuyer;
    }

    function getBestPrice() public view returns (uint256) {
        return bestPrice;
    }

    // seller: hides the price of energy until the end of the timeLock
    // buyer: makes an offer to purchase the energy (participates in the auction), locking in his funds until his bid is exceeded
    
    function energyPurchaseOffer(uint256 _price) public {
        require(block.timestamp <= timeLock, "Time lock expired");
        require(_price > bestPrice, "The price is lower than the current best offer");
        energyCredits.transferCredits(tx.origin, address(this),amount*_price);
        if (bestPrice != 0){
            energyCredits.transferCredits(address(this), bestBuyer ,amount*bestPrice); }
        bestBuyer = tx.origin;
        bestPrice = _price;
    }

    // At the end of the timelock the secret is revealed (energy price decided by the seller) and the highest offer is evaluated
    // if the highest bid is not greater than or equal to the secret price, the funds are returned and the energy is not sold

    function energyHTLCSell(uint256 secretPrice) public returns(bool success){
        require(tx.origin == seller, "You are not the seller");
        require(block.timestamp > timeLock, "Time lock not yet expired");
        require(keccak256(abi.encodePacked(secretPrice)) == hashLock, "Invalid secret");
	
        if (bestPrice >= secretPrice){
            energyCredits.transferCredits(address(this), seller, amount * bestPrice);
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

    function refund() public {
        require(block.timestamp > timeLock, "Time lock not yet expired");
        require(tx.origin == bestBuyer, "nothing to refund");
        require(bestPrice > 0 , "nothing to refund");
        
        energyCredits.transferCredits(address(this), bestBuyer ,amount*bestPrice); 
        bestBuyer = address(0);
        bestPrice = 0;
    }

}