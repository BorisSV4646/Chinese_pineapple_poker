// SPDX-License-Identifier: Apache-2.0 license
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract PineapplePokerToken is ERC20, Ownable {
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    constructor(uint256 initialSupply) ERC20("PineapplePokerToken", "PP") {
        _mint(msg.sender, initialSupply);
    }

    function changeERC20toTokens(
        uint256 amount,
        address tokenAddress
    ) external {
        IERC20 token = IERC20(tokenAddress);
        require(
            tokenAddress == USDT || tokenAddress == USDC || tokenAddress == DAI,
            "Not valid token"
        );
        require(
            token.balanceOf(msg.sender) >= amount,
            "Not enough ERC20 tokens"
        );

        token.transferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);
    }

    function changeTokensToERC20(
        uint256 amount,
        address tokenAddress
    ) external {
        require(
            tokenAddress == USDT || tokenAddress == USDC || tokenAddress == DAI,
            "Not valid token"
        );
        require(
            balanceOf(msg.sender) >= amount,
            "Not enough PineapplePokerTokens"
        );

        _burn(msg.sender, amount);

        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(_msgSender(), amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }
}
