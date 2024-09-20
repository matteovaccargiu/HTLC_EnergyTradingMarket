// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EnergyCredits is ERC20 {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() ERC20("EnergyCredits", "ECR") {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function issueCredits(address user, uint256 credits) public onlyOwner {
        _mint(user, credits);
    }

    function transferCredits(address from, address to, uint256 amount) external {
        require(msg.sender == from, "Can only transfer from own account");
        require(balanceOf(from) >= amount, "Insufficient credits");
        require(from != address(0), "Invalid from address");
        require(to != address(0), "Invalid to address");

        _transfer(from, to, amount);
    }
}
