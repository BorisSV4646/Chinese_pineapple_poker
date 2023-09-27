// SPDX-License-Identifier: Apache-2.0 license
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PineapplePokerToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("PineapplePokerToken", "PP") {
        _mint(msg.sender, initialSupply);
    }

    function mint(uint256 amount) public virtual onlyOwner {
        _mint(_msgSender(), amount);
    }

    function burn(uint256 amount) public virtual onlyOwner {
        _burn(_msgSender(), amount);
    }
}
