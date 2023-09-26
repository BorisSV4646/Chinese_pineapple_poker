// SPDX-License-Identifier: Apache-2.0 license
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract PineapplePoker is Ownable {
    // information is the table open or closed
    enum TableState {
        Active,
        Inactive,
        Showdown
    }

    event NewTableCreated(uint tableId, Table table);
    event NewBuyIn(uint tableId, address player, uint amount);
    event CardsDealt(
        uint tableId,
        uint round,
        bytes32[] cardHashes,
        uint numberPlayer
    );
    event RoundOver(uint tableId, uint round);
    event TableShowdown(uint tableId);
    event AddChips(uint tableId, uint amount, address user);
    event ExitUser(uint tableId, uint amount, address user);
    event CheckCards(uint tableId, address user);

    // deck of cards by suit and value
    struct Card {
        uint8 suit; // 1-4
        uint8 rank; // 1-13
    }
    // characteristics of the game table
    struct Table {
        TableState state;
        uint currentRound; // index of the current round
        uint buyInAmount; // the minimum amount of tokens required to enter the table
        uint pointsCoast; // cost of one point
        uint maxPlayers; // max players on the table
        address[] players; // all players
        IERC20 token; // the token to be used to play in the table
    }
    struct Round {
        bool state; // state of the round, if this is active or not
        uint deals; // number of current deals
        bytes32[][] playerCards;
    }

    uint public totalTables;
    uint private nonce;

    // id => Table
    mapping(uint => Table) public tables;
    // idTable => CardDeck
    mapping(uint256 => Card[]) private decks;
    // idTable => cardHash => card
    mapping(uint => mapping(bytes32 => Card)) private cardHashToNumber;
    // keeps track of the remaining chips of the player in a table
    // player => tableId => remainingChips
    mapping(address => mapping(uint => uint)) public chips;
    // tableId => roundNum => Round
    mapping(uint => mapping(uint => Round)) public rounds;

    /**
     * @notice shuffling a deck of cards
     * @param _tableId id of the table the player is playing on
     * @dev it is necessary to hide or avoid card shuffling manipulations, since the data is open
     */
    function shuffle(uint _tableId) private {
        uint256 deckSize = decks[_tableId].length;
        require(deckSize > 0, "Deck is empty");

        for (uint256 i = 0; i < deckSize; i++) {
            uint256 j = uint256(
                keccak256(abi.encode(block.prevrandao, i, nonce))
            ) % deckSize;
            Card memory tmpCard = decks[_tableId][i];
            decks[_tableId][i] = decks[_tableId][j];
            decks[_tableId][j] = tmpCard;
        }

        nonce += 1;
    }

    /**
     * @notice the function outputs random maps and caches them
     * @param _tableId id of the table the player is playing on
     * @param _numberCards number of cards to be issued
     */
    function getCards(
        uint _tableId,
        uint _numberCards
    ) private returns (bytes32[] memory) {
        uint256 deckSize = decks[_tableId].length;
        bytes32[] memory cardHashes = new bytes32[](_numberCards);
        for (uint256 i = 0; i < _numberCards; i++) {
            uint256 cardNumber = uint256(
                keccak256(abi.encode(block.prevrandao, i, nonce))
            ) % deckSize;
            cardHashes[i] = keccak256(abi.encode(cardNumber));
            cardHashToNumber[_tableId][cardHashes[i]] = decks[_tableId][
                cardNumber
            ];

            // delete card from deck
            decks[_tableId][cardNumber] = decks[_tableId][deckSize - 1];
            decks[_tableId].pop();
        }

        nonce += 1;

        return cardHashes;
    }

    // TODO: need to delete empty table? How?
    /**
     * @notice creates a table
     * @param _buyInAmount the minimum amount of tokens required to enter the table
     * @param _pointsCoast the price of one point on the table
     * @param _maxPlayers the maximum number of players allowed in this table
     * @param _token the token that will be used to bet in this table
     * @dev we check that there can be from 2 to 4 players, creating a table and counting the number of tables
     */
    function createTable(
        uint _buyInAmount,
        uint _pointsCoast,
        uint _maxPlayers,
        address _token
    ) external onlyOwner {
        require(
            _maxPlayers >= 2 && _maxPlayers <= 4,
            "Invalid number of players"
        );
        address[] memory empty;

        for (uint8 suit = 1; suit <= 4; suit++) {
            for (uint8 rank = 1; rank <= 13; rank++) {
                decks[totalTables].push(Card(suit, rank));
            }
        }

        tables[totalTables] = Table({
            state: TableState.Inactive,
            currentRound: 0,
            buyInAmount: _buyInAmount,
            pointsCoast: _pointsCoast,
            maxPlayers: _maxPlayers,
            players: empty,
            token: IERC20(_token)
        });

        emit NewTableCreated(totalTables, tables[totalTables]);

        totalTables += 1;
    }

    /**
     * @notice first the players have to call this method to buy in and enter a table
     * @param _tableId the unique id of the table
     * @param _amount The amount of tokens to buy in the table. (must be greater than or equal to the minimum table buy in amount)
     */
    function buyIn(uint _tableId, uint _amount) external {
        require(tables[_tableId].buyInAmount != 0, "Table not created");

        Table storage table = tables[_tableId];

        require(_amount >= table.buyInAmount, "Not enough buyInAmount");
        require(table.players.length < table.maxPlayers, "Table full");

        // !need to approve from user first
        // transfer buyIn Amount from player to contract
        require(table.token.transferFrom(msg.sender, address(this), _amount));
        chips[msg.sender][_tableId] += _amount;

        // add player to table
        table.players.push(msg.sender);

        emit NewBuyIn(_tableId, msg.sender, _amount);
    }

    /**
     * @notice This method will be called by the owner to send the hash of the cards to all the players.
     * The key of the hash and the card itself will be sent privately by the owner to the player event is
     * kept onchain so that other players can later verify that there was no cheating.
     * This will deal the cards to the players and start the round
     * @param _tableId the unique id of the table
     */
    function dealCards(uint _tableId) external onlyOwner {
        Table storage table = tables[_tableId];
        require(table.state == TableState.Inactive, "Game already going on");
        require(
            allPlayersHaveMinBalance(_tableId),
            "Not all players have the minimum balance"
        );

        Round storage round = rounds[_tableId][table.currentRound];
        table.state = TableState.Active;
        round.state = true;

        for (uint i = 0; i < table.players.length; i++) {
            shuffle(_tableId);
            bytes32[] memory cardsForPlayer = getCards(_tableId, 5);
            emit CardsDealt(_tableId, table.currentRound, cardsForPlayer, i);
            round.playerCards[i] = cardsForPlayer; // Simplified card assignment
        }
    }

    /**
     * @notice The function distributes three cards to users and does it 4 times per round
     * @param _tableId the unique id of the table
     */
    function newDeal(uint _tableId) external onlyOwner {
        Table storage table = tables[_tableId];
        require(table.state == TableState.Active, "Game not started");
        Round storage round = rounds[_tableId][table.currentRound];
        require(round.deals < 4, "All cards have been dealt");
        round.deals += 1;

        for (uint i = 0; i < table.players.length; i++) {
            shuffle(_tableId);
            bytes32[] memory cardsForPlayer = getCards(_tableId, 3);
            emit CardsDealt(_tableId, table.currentRound, cardsForPlayer, i);
            round.playerCards[i] = cardsForPlayer; // Simplified card assignment
        }
    }

    /**
     * @notice The function completes the current round, calculates the rewards
     * @param _tableId the unique id of the table
     * @param _playersPoints players' points
     * @param raiseOrLose decrease or add points to the user
     */
    function endRound(
        uint _tableId,
        uint[] memory _playersPoints,
        bool[] memory raiseOrLose
    ) external onlyOwner {
        Table storage table = tables[_tableId];
        require(table.state == TableState.Active, "Game not started");
        Round storage round = rounds[_tableId][table.currentRound];
        require(round.deals == 4, "Not all cards have been dealt");

        table.state = TableState.Showdown;
        table.currentRound += 1;
        round.state = false;

        uint lenght = table.players.length;

        for (uint i = 0; i < lenght; i++) {
            uint playerChips = chips[table.players[i]][_tableId];
            uint totalEarn = _playersPoints[i] * table.pointsCoast;
            // change players balances
            if (raiseOrLose[i]) {
                playerChips += totalEarn;
                chips[table.players[i]][_tableId] = playerChips;
            } else {
                playerChips = (totalEarn >= playerChips)
                    ? 0
                    : playerChips - totalEarn;
                chips[table.players[i]][_tableId] = playerChips;
            }
        }

        emit RoundOver(_tableId, table.currentRound - 1);
    }

    /**
     * @notice add tokens to participate in the next round of the game
     * @param _tableId id of the table the player is playing on
     * @param _amount the amount of tokens to buy in the table
     */
    function addChips(uint _tableId, uint _amount) external {
        Table storage table = tables[_tableId];
        require(
            isPlayerInTable(msg.sender, table.players),
            "Not a player in this table"
        );

        require(table.token.transferFrom(msg.sender, address(this), _amount));
        chips[msg.sender][_tableId] += _amount;

        emit AddChips(_tableId, _amount, msg.sender);
    }

    /**
     * @notice function for exiting the table and withdrawing chips
     * @param _tableId id of the table the player is playing on
     * @dev the function checks that the round is inactive and the user has a balance of chips to withdraw
     */
    function withdrawAndExit(uint _tableId) external {
        require(
            tables[_tableId].state == TableState.Showdown,
            "Round is active"
        );
        require(chips[msg.sender][_tableId] > 0, "Not enough balance");
        uint256 _amount = chips[msg.sender][_tableId];
        chips[msg.sender][_tableId] = 0;
        require(tables[_tableId].token.transfer(msg.sender, _amount));

        removePlayer(_tableId, msg.sender);

        if (tables[_tableId].players.length == 0) {
            tables[_tableId].state == TableState.Inactive;
        }

        emit ExitUser(_tableId, _amount, msg.sender);
    }

    /**
     * @notice removes the user from the table if he does not continue playing
     * @param _tableId id of the table the player is playing on
     * @param playerToRemove the player's address to delete
     */
    function deleteUserFrontend(
        uint _tableId,
        address playerToRemove
    ) external onlyOwner {
        Table storage table = tables[_tableId];
        require(
            isPlayerInTable(msg.sender, table.players),
            "Not a player in this table"
        );

        removePlayer(_tableId, playerToRemove);
    }

    /**
     * @notice the user checks his cards in the blockchain
     * @param _tableId id of the table the player is playing on
     */
    function checkingCards(
        uint _tableId
    ) external view returns (Card[] memory) {
        Table storage table = tables[_tableId];
        require(
            isPlayerInTable(msg.sender, table.players),
            "Not a player in this table"
        );

        uint index = getPlayerIndex(_tableId, msg.sender);

        return getCardNumbersForPlayer(_tableId, table.currentRound - 1, index);
    }

    /**
     * @notice checks whether the address is a player on this table
     * @param _player player, who add chips
     * @param _players all players table
     */
    function isPlayerInTable(
        address _player,
        address[] memory _players
    ) internal pure returns (bool) {
        for (uint i = 0; i < _players.length; i++) {
            if (_player == _players[i]) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice checks that all players have a minimum balance for the game
     * @param _tableId id of the table the player is playing on
     */
    function allPlayersHaveMinBalance(
        uint _tableId
    ) internal view returns (bool) {
        Table storage table = tables[_tableId];
        for (uint i = 0; i < table.players.length; i++) {
            if (chips[table.players[i]][_tableId] < table.buyInAmount) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice remove the player when leaving the table
     * @param _tableId id of the table the player is playing on
     * @param playerToRemove the player's address to delete
     */
    function removePlayer(uint _tableId, address playerToRemove) internal {
        Table storage table = tables[_tableId];
        uint indexToRemove = table.players.length; // set to an invalid index initially
        // Find the index of the player to remove
        for (uint i = 0; i < table.players.length; i++) {
            if (table.players[i] == playerToRemove) {
                indexToRemove = i;
                break;
            }
        }

        require(
            indexToRemove != table.players.length,
            "Player not found in table"
        );
        // If the player is not the last one in the array, swap with the last one
        if (indexToRemove != table.players.length - 1) {
            table.players[indexToRemove] = table.players[
                table.players.length - 1
            ];
        }
        // Remove the last player (which is now the player to remove)
        table.players.pop();
    }

    /**
     * @notice find out the index of the user's address in the array of users at the table
     * @param _tableId id of the table the player is playing on
     * @param _player the player's address to know index
     */
    function getPlayerIndex(
        uint _tableId,
        address _player
    ) internal view returns (uint) {
        Table storage table = tables[_tableId];
        for (uint i = 0; i < table.players.length; i++) {
            if (table.players[i] == _player) {
                return i;
            }
        }
        revert("Player not found");
    }

    /**
     * @notice returns an array Card[] of user cards
     * @param _tableId id of the table the player is playing on
     * @param _roundId the number of the last round
     * @param playerNumber the player's index
     */
    function getCardNumbersForPlayer(
        uint _tableId,
        uint _roundId,
        uint playerNumber
    ) internal view returns (Card[] memory) {
        require(
            playerNumber >= 1 && playerNumber <= 4,
            "Invalid player number"
        );

        Round storage round = rounds[_tableId][_roundId];
        bytes32[] memory playerCards = round.playerCards[playerNumber - 1];

        Card[] memory checkCardsUser = new Card[](playerCards.length);
        for (uint i = 0; i < playerCards.length; i++) {
            checkCardsUser[i] = cardHashToNumber[_tableId][playerCards[i]];
        }

        return checkCardsUser;
    }
}
