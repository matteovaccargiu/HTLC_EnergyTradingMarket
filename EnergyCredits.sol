// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EnergyCredits is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() ERC20("EnergyCredits", "ECR") {
        // Assign the administrator role to the account distributing the contract
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Assign the role of minter to the account distributing the contract
        _grantRole(MINTER_ROLE, msg.sender);

        emit OwnershipTransferred(address(0), msg.sender);
    }

    function issueCredits(address user, uint256 credits) public onlyRole(MINTER_ROLE) {
        _mint(user, credits);
    }

    // Function for assigning the minter role to an account
    function grantMinterRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    // Funzione per revocare il ruolo di minter da un account
    function revokeMinterRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }
}
