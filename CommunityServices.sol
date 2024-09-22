// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EnergyCredits.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CommunityServices is ReentrancyGuard {
    IERC20 public energyCredits;

    struct Service{
        uint256 price;
        string name;
        address serviceProvider; 
    }

    mapping( uint256=> Service) services;
    uint256 numServices;

    constructor(address _energyCreditsAddress) {
        energyCredits = IERC20(_energyCreditsAddress);
    }

    function addService(Service memory _service) public {
        services[numServices] = _service;
        numServices += 1;
    }

    function purchaseService(uint256 idService) public nonReentrant {
        require(idService < numServices, "Service does not exist");
        require(energyCredits.allowance(msg.sender, address(this)) >= services[idService].price, "Insufficient allowance");
        require(energyCredits.balanceOf(msg.sender) >= services[idService].price, "Insufficient balance");

        energyCredits.transferFrom(msg.sender, services[idService].serviceProvider, services[idService].price);
    } 
}

