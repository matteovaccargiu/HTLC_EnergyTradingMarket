# HTLC_EnergyTradingMarket

This repository contains Solidity smart contracts for a Peer-to-Peer (P2P) energy trading platform using Hashed Time-Locked Contracts (HTLC). The contracts facilitate decentralized energy trading and community services, utilizing a custom ERC20 token named EnergyCredits. The platform allows users to buy, sell, and trade energy credits in a secure and transparent manner.

The repository contains the following smart contracts, each split into separate .sol files:

## 1. HTLCEnergyMarket.sol
This contract implements the HTLC (Hashed Time-Locked Contract) logic for energy trading between buyers and sellers. Sellers hide the price of energy, and buyers place bids. The contract ensures that funds are locked until a certain condition is met (the secret price is revealed and a buyer has placed a valid bid).

### Key Features:

 **Bidding system:** Buyers place bids for energy until the time lock expires.
- **Secret energy price:** Sellers hide the price using a hash lock, which is revealed at the end of the time lock.
- **HTLC mechanism:** Securely locks and transfers funds until the correct conditions are met.
- **Refund mechanism:** Allows buyers to refund their bids if the conditions aren't met.

## 2. P2PEnergyTrading.sol
This contract manages the users and energy offers. Users with authorized smart meters can register and update their energy data. It also allows users to create energy offers that are traded using HTLC logic.

### Key Features:

- **User Registration:** Users with authorized smart meters can register and update their energy production and consumption data.
- **Energy Offers:** Allows sellers to create energy offers based on their energy production and participate in HTLC-based auctions.
- **Energy Trading:** Buyers can place bids, and sellers reveal the secret price to finalize the sale.

## 3. EnergyCredits.sol
This contract implements an ERC20 token named EnergyCredits (ECR), which is used as the currency for the energy trading platform. The contract includes minting, transferring, and spending functionalities.

### Key Features:

- **ERC20 Implementation:** Provides standard ERC20 functionalities.
- **Minting:** The owner can mint new tokens to reward users for renewable energy production.
- **Transfer Credits:** Energy credits can be transferred between users during energy trades or community service payments.

## 4. CommunityServices.sol
This contract allows users to purchase community services using EnergyCredits. Service providers can list their services, and users can pay for them with energy credits.

### Key Features:

- **Service Listing:** Service providers can list their services with a price.
- **Service Purchase:** Users can purchase services using their energy credits.

## Folder Structure

```
contracts/
│
├── HTLCEnergyMarket.sol        # Implements the HTLC energy auction logic.
├── P2PEnergyTrading.sol        # Manages user data, energy offers, and HTLC integration.
├── EnergyCredits.sol           # ERC20 token for energy credits.
└── CommunityServices.sol       # Handles purchasing services using energy credits.
```
