// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EnergyCredits.sol";
import "./P2PEnergyTrading.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CommunityServices is ReentrancyGuard {
    IERC20 public immutable energyCredits;
    P2PEnergyTrading public p2pEnergyTrading;

    struct Service {
        uint256 price;
        string name;
        address serviceProvider; 
        bool isActive;
    }

    mapping(uint256 => Service) public services;
    mapping(address => mapping(string => bool)) public existingServices;
    uint256 public numServices;

    event ServiceAdded(uint256 serviceId, string name, uint256 price, address serviceProvider);
    event ServicePurchased(uint256 serviceId, address buyer);

    constructor(address _energyCreditsAddress, address _p2pEnergyTradingAddress) {
        energyCredits = IERC20(_energyCreditsAddress);
        p2pEnergyTrading = P2PEnergyTrading(_p2pEnergyTradingAddress);
    }

    function addService(uint256 _price, string memory _name) public {
        require(p2pEnergyTrading.isUserRegistered(msg.sender), "You must be a registered user to add a service");
        require(!existingServices[msg.sender][_name], "Service already exists");
        require(_price > 0, "Price must be greater than zero");

        services[numServices] = Service({
            price: _price,
            name: _name,
            serviceProvider: msg.sender,
            isActive: true
        });

        emit ServiceAdded(numServices, _name, _price, msg.sender);
        existingServices[msg.sender][_name] = true;
        numServices += 1;
    }

    function removeService(uint256 idService) public {
        require(idService < numServices, "Service does not exist");
        Service storage service = services[idService];
        require(msg.sender == service.serviceProvider, "Only the service provider can remove the service");
        service.isActive = false;
    }

    function purchaseService(uint256 idService) public nonReentrant {
        require(idService < numServices, "Service does not exist");
        Service memory service = services[idService];
        require(service.isActive, "Service is not active");
        require(energyCredits.allowance(msg.sender, address(this)) >= service.price, "Insufficient allowance");
        require(energyCredits.balanceOf(msg.sender) >= service.price, "Insufficient balance");

        energyCredits.transferFrom(msg.sender, service.serviceProvider, service.price);

        emit ServicePurchased(idService, msg.sender);
    } 
}
