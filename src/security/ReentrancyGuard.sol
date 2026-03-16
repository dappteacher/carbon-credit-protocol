// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

error Reentrancy();

contract ReentrancyGuard {
    uint256 private locked = 1;

    modifier nonReentrant() {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }
}
