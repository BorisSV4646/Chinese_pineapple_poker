// SPDX-License-Identifier: Apache-2.0 license
pragma solidity ^0.8.19;

contract Shuffle {
    // deck of cards by suit and value
    struct Card {
        uint8 suit; // 1-4
        uint8 rank; // 1-13
    }

    // the location of the cards in the deck
    Card[] public deck;

    /**
     * @notice creating a deck of cards in order from 0 to 51 cards
     */
    constructor() {
        for (uint8 suit = 1; suit <= 4; suit++) {
            for (uint8 rank = 1; rank <= 13; rank++) {
                deck.push(Card(suit, rank));
            }
        }
    }

    /**
     * @notice shuffling a deck of cards
     * @dev it is necessary to hide or avoid card shuffling manipulations, since the data is open
     */
    function shuffle() external {
        uint256 deckSize = deck.length;
        for (uint256 i = 0; i < deckSize; i++) {
            uint256 j = uint256(keccak256(abi.encode(block.prevrandao, i))) %
                deckSize;
            Card memory tmpCard = deck[i];
            deck[i] = deck[j];
            deck[j] = tmpCard;
        }
    }
}
