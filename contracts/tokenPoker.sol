// SPDX-License-Identifier: Apache-2.0 license
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PineapplePoker is ERC20 {
    constructor(uint256 initialSupply) ERC20("PineapplePoker", "PP") {
        _mint(msg.sender, initialSupply);
    }
}
