// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TipJar
/// @notice Accepts ETH tips, tracks per-address totals, lets the owner withdraw the balance.
contract TipJar is Ownable {
    /// @notice Cumulative amount tipped by each address (lifetime, never decreases).
    mapping(address => uint256) public totalTipped;

    /// @notice Cumulative amount ever received by the contract (lifetime, not current balance).
    uint256 public totalReceived;

    event Tipped(address indexed from, uint256 amount, uint256 newTotal);

    constructor() Ownable(msg.sender) {}

    /// @notice Deposit a tip. Reverts on a zero-value call.
    function deposit() external payable {
        require(msg.value > 0, "TipJar: zero deposit");

        uint256 newTotal = totalTipped[msg.sender] + msg.value;
        totalTipped[msg.sender] = newTotal;
        totalReceived += msg.value;

        emit Tipped(msg.sender, msg.value, newTotal);
    }

    /// @notice Withdraw the entire current contract balance to the owner.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "TipJar: nothing to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "TipJar: withdraw failed");
    }

    /// @notice Allow plain ETH transfers (no calldata) to count as a tip too.
    receive() external payable {
        require(msg.value > 0, "TipJar: zero deposit");

        uint256 newTotal = totalTipped[msg.sender] + msg.value;
        totalTipped[msg.sender] = newTotal;
        totalReceived += msg.value;

        emit Tipped(msg.sender, msg.value, newTotal);
    }
}
