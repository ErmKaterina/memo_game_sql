CREATE TABLE players (
    nickname VARCHAR2(100) PRIMARY KEY,
    password_hash VARCHAR2(100) NOT NULL
);

-- Создание таблицы player_results
CREATE TABLE player_results (
    nickname VARCHAR2(100) PRIMARY KEY,
    games_played NUMBER DEFAULT 0,
    games_won NUMBER DEFAULT 0,
    total_points NUMBER DEFAULT 0,
    CONSTRAINT fk_player_results_nickname FOREIGN KEY (nickname) REFERENCES players(nickname)
);

-- Создание таблицы game_cards с составным первичным ключом (card_id, game_nick)
CREATE TABLE game_cards (
    card_id NUMBER,
    game_nick VARCHAR2(100),
    card_value VARCHAR2(10),
    is_opened CHAR(1) DEFAULT 'N' CHECK (is_opened IN ('Y', 'N')),
    move_timestamp TIMESTAMP,
    CONSTRAINT pk_game_cards PRIMARY KEY (card_id, game_nick),
    CONSTRAINT fk_game_cards_nickname FOREIGN KEY (game_nick) REFERENCES players(nickname)
);