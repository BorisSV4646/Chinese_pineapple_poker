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
    event CardsDealt(uint tableId);
    event RoundOver(uint tableId, uint round);
    event CommunityCardsDealt(uint tableId, uint roundId, uint8[] cards);
    event TableShowdown(uint tableId);

    // deck of cards by suit and value
    struct Card {
        uint8 suit; // 1-4
        uint8 rank; // 1-13
    }
    // how the player lays out the cards
    // ?может не нужно
    struct PlayerHands {
        uint8[] topHand; // 3 cards
        uint8[] middleHand; // 5 cards
        uint8[] bottomHand; // 5 cards
    }
    // characteristics of the game table
    struct Table {
        TableState state;
        uint totalHands; // total Hands till now
        uint currentRound; // index of the current round
        uint buyInAmount; // the minimum amount of tokens required to enter the table
        uint pointsCoast; // cost of one point
        uint maxPlayers; // max players on the table
        address[] players; // all players
        IERC20 token; // the token to be used to play in the table
    }
    struct Round {
        bool state; // state of the round, if this is active or not
        address[] players;
        bytes32[] cardPlayer1;
        bytes32[] cardPlayer2;
        bytes32[] cardPlayer3;
        bytes32[] cardPlayer4;
    }
    struct PlayerCardHashesFirst {
        bytes32 card1Hash;
        bytes32 card2Hash;
        bytes32 card3Hash;
        bytes32 card4Hash;
        bytes32 card5Hash;
    }
    struct PlayerCardHashes {
        bytes32 card1Hash;
        bytes32 card2Hash;
        bytes32 card3Hash;
    }

    uint public totalTables;
    uint private nonce;

    // id => Table
    mapping(uint => Table) public tables;
    // idTable => CardDeck
    mapping(uint256 => Card[]) private decks;
    // idTable => cardHash => cardNumber
    mapping(uint => mapping(bytes32 => uint256)) private cardHashToNumber;
    // keeps track of the remaining chips of the player in a table
    // player => tableId => remainingChips
    mapping(address => mapping(uint => uint)) public chips;
    // player => tableId => handNum => PlayerCardHashesFirst
    mapping(address => mapping(uint => mapping(uint => PlayerCardHashesFirst)))
        public playerHashesFirst;
    // player => tableId => deal => handNum => PlayerCardHashes
    mapping(address => mapping(uint => mapping(uint => mapping(uint => PlayerCardHashes))))
        public playerHashes;
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

    // TODO: сделать еще хэширование выдаваемых картм и исключение из колоды

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
            cardHashToNumber[_tableId][cardHashes[i]] = cardNumber;

            // delete card from deck
            decks[_tableId][cardNumber] = decks[_tableId][deckSize - 1];
            decks[_tableId].pop();
        }

        nonce += 1;

        return cardHashes;
    }

    /**
     * @notice function for exiting the table and withdrawing chips
     * @param _tableId id of the table the player is playing on
     * @dev the function checks that the round is inactive and the user has a balance of chips to withdraw
     */
    function withdrawAndExit(uint _tableId) external {
        require(
            tables[_tableId].state == TableState.Inactive,
            "Round is active"
        );
        require(chips[msg.sender][_tableId] > 0, "Not enough balance");
        uint256 _amount = chips[msg.sender][_tableId];
        chips[msg.sender][_tableId] = 0;
        require(tables[_tableId].token.transfer(msg.sender, _amount));
    }

    // TODO: need to delete empty table? How?
    // ? CREATER call this function
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
            totalHands: 0,
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
     * @dev first the players have to call this method to buy in and enter a table
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
     * @dev This method will be called by the owner to send the hash of the cards to all the players.
     * The key of the hash and the card itself will be sent privately by the owner to the player event is
     * kept onchain so that other players can later verify that there was no cheating.
     * This will deal the cards to the players and start the round
     * @param _tableId the unique id of the table
     */
    function dealCards(uint _tableId) external onlyOwner {
        Table storage table = tables[_tableId];
        uint n = table.players.length;
        require(table.state == TableState.Inactive, "Game already going on");
        table.state = TableState.Active;

        // initiate the first round
        Round storage round = rounds[_tableId][0];

        round.state = true;
        round.players = table.players;

        for (uint i = 0; i < n; i++) {
            // shuffle card deck
            shuffle(_tableId);
            // get 5 first card for user
            bytes32[] memory _playerCards = getCards(_tableId, 5);
            require(
                n > 1 && _playerCards.length == 5,
                "ERROR: PlayerCardHashes Length"
            );
            // сonverting user hashes into a hash structure
            PlayerCardHashesFirst memory playerCardHashes;
            playerCardHashes.card1Hash = _playerCards[0];
            playerCardHashes.card2Hash = _playerCards[1];
            playerCardHashes.card3Hash = _playerCards[2];
            playerCardHashes.card4Hash = _playerCards[3];
            playerCardHashes.card5Hash = _playerCards[4];
            // save the player hashes for later use in showdown()
            playerHashesFirst[table.players[i]][_tableId][
                table.totalHands
            ] = playerCardHashes;
        }

        emit CardsDealt(_tableId);
    }

    function newDeal(uint _tableId, uint _numberDeal) external onlyOwner {
        Table storage table = tables[_tableId];
        uint n = table.players.length;
        require(table.state == TableState.Active, "Game not start");

        require(_numberDeal > 0 && _numberDeal <= 4, "Incorrect round");

        for (uint i = 0; i < n; i++) {
            // shuffle card deck
            shuffle(_tableId);
            // get 5 first card for user
            bytes32[] memory _playerCards = getCards(_tableId, 3);
            require(
                n > 1 && _playerCards.length == 5,
                "ERROR: PlayerCardHashes Length"
            );
            // сonverting user hashes into a hash structure
            PlayerCardHashes memory playerCardHashes;
            playerCardHashes.card1Hash = _playerCards[0];
            playerCardHashes.card2Hash = _playerCards[1];
            playerCardHashes.card3Hash = _playerCards[2];
            // save the player hashes for later use in showdown()
            playerHashes[table.players[i]][_tableId][_numberDeal][
                table.totalHands
            ] = playerCardHashes;

            //! надо добавить раунд в раздачу первых пяти карт? зачем в мэппинге handNum?
        }

        emit CardsDealt(_tableId);
    }
}
