// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnergyCredits.sol";

contract CommunityServices {
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

    function purchaseService(uint256 idService) public {
        energyCredits.transferFrom(msg.sender, services[idService].serviceProvider, services[idService].price);
    } 
}
