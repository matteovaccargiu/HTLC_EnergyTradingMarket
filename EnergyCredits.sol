// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EnergyCredits is ERC20 {

    address owner;
    
    constructor() ERC20("EnergyCredits", "ECR") {
        owner = msg.sender;
    }

    function issueCredits(address user, uint256 credits) public  {
        require(msg.sender == owner, "Only the owner");
        _mint(user, credits);
    }

    function transferCredits(address from, address to, uint256 amount) public {
        require(balanceOf(from) >= amount, "Insufficient credits");
        require(from != address(0), "Invalid from address");
        require(to != address(0), "Invalid to address");

        _transfer(from, to, amount);
    }
}