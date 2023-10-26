// SPDX-License-Identifier: Apache-2.0 license
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract PineapplePokerToken is ERC20, Ownable {
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

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

        require(token.transferFrom(msg.sender, address(this), amount));

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

        require(IERC20(tokenAddress).transfer(msg.sender, amount));
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(_msgSender(), amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }
}
