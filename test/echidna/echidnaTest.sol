// SPDX-License-Identifier: Apache-2.0 license
pragma solidity ^0.8.19;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract PineapplePoker is Ownable {
    // information is the table open or closed
    enum TableState {
        Inactive,
        Active,
        Showdown
    }

    event NewTableCreated(uint tableId, Table table);
    event NewBuyIn(uint tableId, address player, uint amount);
    event CardsDealtFirst(
        uint tableId,
        uint round,
        bytes32[] cardHashes,
        uint numberPlayer
    );
    event CardsDealtSecond(
        uint tableId,
        uint round,
        bytes32[] cardHashes,
        uint numberPlayer,
        uint numberDeal
    );
    event RoundOver(uint tableId, uint round);
    event TableShowdown(uint tableId);
    event AddChips(uint tableId, uint amount, address user);
    event ExitUser(uint tableId, uint amount, address user);
    event CheckCards(uint tableId, address user);
    event DeleteUser(uint tableId, address playerToRemove);
    event TableReady(uint tableId, uint quantityPlayers);

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
    function shuffle(uint _tableId, address _user) private {
        uint256 deckSize = decks[_tableId].length;
        require(deckSize > 0, "Deck is empty");

        for (uint256 i = 0; i < deckSize; i++) {
            uint256 j = uint256(
                keccak256(abi.encode(block.prevrandao, i, nonce, _user))
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
        uint _numberCards,
        address _user
    ) private returns (bytes32[] memory) {
        uint256 deckSize = decks[_tableId].length;
        bytes32[] memory cardHashes = new bytes32[](_numberCards);
        for (uint256 i = 0; i < _numberCards; i++) {
            uint256 cardNumber = uint256(
                keccak256(abi.encode(block.prevrandao, i, nonce, _user))
            ) % deckSize;
            cardHashes[i] = keccak256(abi.encode(cardNumber, i, nonce, _user));
            cardHashToNumber[_tableId][cardHashes[i]] = decks[_tableId][
                cardNumber
            ];

            // delete card from deck
            decks[_tableId][cardNumber] = decks[_tableId][deckSize - 1];
            decks[_tableId].pop();
            deckSize--;
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

        if (table.players.length >= 2) {
            emit TableReady(_tableId, table.players.length);
        }

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
        require(table.state != TableState.Active, "Game already going on");
        require(
            allPlayersHaveMinBalance(_tableId),
            "Not all players have the minimum balance"
        );

        Round storage round = rounds[_tableId][table.currentRound];
        table.state = TableState.Active;
        round.state = true;

        for (uint i = 0; i < table.players.length; i++) {
            round.playerCards.push(new bytes32[](0));
        }

        for (uint i = 0; i < table.players.length; i++) {
            shuffle(_tableId, table.players[i]);
            bytes32[] memory cardsForPlayer = getCards(
                _tableId,
                5,
                table.players[i]
            );
            emit CardsDealtFirst(
                _tableId,
                table.currentRound,
                cardsForPlayer,
                i
            );
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
            shuffle(_tableId, table.players[i]);
            bytes32[] memory cardsForPlayer = getCards(
                _tableId,
                3,
                table.players[i]
            );
            emit CardsDealtSecond(
                _tableId,
                table.currentRound,
                cardsForPlayer,
                i,
                round.deals - 1
            );
            for (uint j = 0; j < cardsForPlayer.length; j++) {
                round.playerCards[i].push(cardsForPlayer[j]);
            }
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
     * @notice function for a player to exit the table, withdraw chips, and remove the player from the table
     * @param _tableId id of the table the player is playing on
     * @param playerAddress address of the player who wants to exit (this can be the caller or another player if the caller is the owner)
     */
    function exitTable(uint _tableId, address playerAddress) external {
        require(
            tables[_tableId].state == TableState.Showdown,
            "Round is active"
        );
        require(
            chips[playerAddress][_tableId] > 0 ||
                isPlayerInTable(playerAddress, tables[_tableId].players),
            "Not a valid player or not enough balance"
        );

        // If the function caller is not the playerAddress, ensure the caller is the owner
        if (msg.sender != playerAddress) {
            require(
                msg.sender == owner(),
                "Only the owner can remove other players"
            );
        }

        uint256 _amount = chips[playerAddress][_tableId];
        chips[playerAddress][_tableId] = 0;
        require(tables[_tableId].token.transfer(playerAddress, _amount));

        removePlayer(_tableId, playerAddress);

        if (tables[_tableId].players.length == 0) {
            tables[_tableId].state = TableState.Inactive;
        }

        if (msg.sender == playerAddress) {
            emit ExitUser(_tableId, _amount, playerAddress);
        } else {
            emit DeleteUser(_tableId, playerAddress);
        }
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
            tables[_tableId].state == TableState.Showdown,
            "Round is active"
        );
        require(
            isPlayerInTable(msg.sender, table.players),
            "Not a player in this table"
        );

        uint index = getPlayerIndex(_tableId, msg.sender);

        return getCardNumbersForPlayer(_tableId, table.currentRound - 1, index);
    }

    /**
     * @notice the frontend checks cards users in the blockchain
     * @param _tableId id of the table the player is playing on
     */
    function checkingCardsFrontend(
        uint _tableId
    ) external view onlyOwner returns (Card[][] memory) {
        Table storage table = tables[_tableId];
        uint playersCount = table.players.length;

        Card[][] memory checkCardsUser = new Card[][](playersCount);

        uint currentRound = (table.state == TableState.Showdown)
            ? table.currentRound - 1
            : table.currentRound;

        for (uint i = 0; i < playersCount; i++) {
            checkCardsUser[i] = getCardNumbersForPlayer(
                _tableId,
                currentRound,
                i
            );
        }

        return checkCardsUser;
    }

    /**
     * @notice checks whether the address is a player on this table
     * @param _player player, who add chips
     * @param _players all players table
     */
    function isPlayerInTable(
        address _player,
        address[] memory _players
    ) private pure returns (bool) {
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
    ) private view returns (bool) {
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
    function removePlayer(uint _tableId, address playerToRemove) private {
        Table storage table = tables[_tableId];
        uint indexToRemove = getPlayerIndex(_tableId, playerToRemove);

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
    ) private view returns (uint) {
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
    ) private view returns (Card[] memory) {
        require(
            playerNumber >= 0 && playerNumber <= 3,
            "Invalid player number"
        );

        Round storage round = rounds[_tableId][_roundId];
        bytes32[] memory playerCards = round.playerCards[playerNumber];

        Card[] memory checkCardsUser = new Card[](playerCards.length);
        for (uint i = 0; i < playerCards.length; i++) {
            checkCardsUser[i] = cardHashToNumber[_tableId][playerCards[i]];
        }

        return checkCardsUser;
    }
}

contract EchidnaTest is PineapplePoker {
    // Проверка, что после создания стола его состояние "Неактивно"
    function echidna_test_new_table_inactive() public view returns (bool) {
        return tables[totalTables - 1].state == TableState.Inactive;
    }

    // Проверка, что после создания стола у него нет игроков
    function echidna_test_new_table_no_players() public view returns (bool) {
        return tables[totalTables - 1].players.length == 0;
    }

    // Проверка, что после создания стола текущий раунд равен 0
    function echidna_test_new_table_round_zero() public view returns (bool) {
        return tables[totalTables - 1].currentRound == 0;
    }
}
