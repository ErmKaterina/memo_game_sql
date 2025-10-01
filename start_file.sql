-- Регистрация игрока
BEGIN
    player_level_pkg.register_player('13333', '12345678');
END;

-- Вход под логином
BEGIN
    player_level_pkg.login('13333', '12345678');
END;



-- Задание уровня (от 1 до 10)
BEGIN
    player_level_pkg.set_level('2');
END;

-- Задание количества пар (от 5 до 30)
BEGIN
    player_level_pkg.set_pairs('5');
END;



-- Запуск игры
BEGIN
    player_level_pkg.start_game;
END;

--Статус игры
BEGIN
    player_level_pkg.track_game_status;
END;

-- Попытка хода (id1 карточки, id2 карточки)
BEGIN
    player_level_pkg.make_move('2', '4');
END;


--Выход из игры
BEGIN
    player_level_pkg.exit_game;
END;

--выход из игры и пользователя
BEGIN
   developer.player_level_pkg.logout;
END;

--Вывод топа игроков
BEGIN
    player_level_pkg.show_top;
END;



--для игрока, который не администратор

--регистрация
BEGIN
    developer.player_level_pkg.register_player('0', '12345678');
END;
-- вход по логину
BEGIN
    developer.player_level_pkg.login('0', '12345678');
END;

--установка уровня (от 1 до 10)
BEGIN
    developer.player_level_pkg.set_level('10');
END;

-- Задание количества пар (от 5 до 30)
BEGIN
    developer.player_level_pkg.set_pairs('6');
END;


-- Запуск игры
BEGIN
    developer.player_level_pkg.start_game;
END;
--ходы
BEGIN
    developer.player_level_pkg.make_move('9','6');
END;
--статус игры
BEGIN
    developer.player_level_pkg.track_game_status;
END;

--топ игроков
BEGIN
    developer.player_level_pkg.show_top;
END;

--выход из игры
BEGIN
    developer.player_level_pkg.exit_game;
END;

--выход из игры и пользователя
BEGIN
   developer.player_level_pkg.logout;
END;