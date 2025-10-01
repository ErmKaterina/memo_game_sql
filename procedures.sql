
CREATE OR REPLACE PACKAGE BODY player_level_pkg AS
    g_player_level NUMBER;
    g_pairs_number NUMBER;
    g_job_name VARCHAR2(100);
    g_session_id NUMBER;

    FUNCTION verify_password(
        p_nick IN VARCHAR2,
        p_password IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_stored_hash VARCHAR2(100);
    BEGIN
        SELECT password_hash INTO v_stored_hash
        FROM players
        WHERE nickname = p_nick;
        RETURN v_stored_hash = p_password;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END verify_password;

    PROCEDURE check_auth IS
    BEGIN
        IF NOT g_is_authenticated THEN
            RAISE_APPLICATION_ERROR(-20001, 'Сначала войдите в игру с помощью никнейма и пароля');
        END IF;
        IF g_current_username IS NULL THEN
            RAISE_APPLICATION_ERROR(-20040, 'Текущий никнейм не установлен');
        END IF;
    END check_auth;

    PROCEDURE check_game_not_started IS
        v_game_started NUMBER;
    BEGIN
        IF g_current_username IS NOT NULL THEN
            SELECT COUNT(*) INTO v_game_started FROM game_cards WHERE game_nick = g_current_username;
            IF v_game_started > 0 THEN
                RAISE_APPLICATION_ERROR(-20035, 'Игра уже началась! Нельзя выполнять это действие, пока не завершите игру с помощью logout.');
            END IF;
        END IF;
    END check_game_not_started;

    FUNCTION get_move_time_limit RETURN NUMBER IS
    BEGIN
        IF g_player_level IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Уровень не установлен');
        END IF;
        RETURN 60 - (g_player_level - 1) * 5;
    END get_move_time_limit;

    PROCEDURE register_player(p_nick VARCHAR2, p_password VARCHAR2) IS
        v_count NUMBER;
        v_nick VARCHAR2(100);
    BEGIN
        check_game_not_started;
        IF p_nick IS NULL OR TRIM(p_nick) = '' THEN
            RAISE_APPLICATION_ERROR(-20017, 'Никнейм не может быть пустым или состоять только из пробелов!');
            RETURN;
        END IF;
        IF INSTR(p_nick, ' ') > 0 THEN
            RAISE_APPLICATION_ERROR(-20018, 'Никнейм не должен содержать пробелы!');
            RETURN;
        END IF;
        IF LENGTH(p_nick) NOT BETWEEN 1 AND 20 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Никнейм должен быть от 1 до 20 символов');
            RETURN;
        END IF;
        IF NOT REGEXP_LIKE(p_nick, '^[a-zA-Zа-яА-Я0-9_]+$') THEN
            RAISE_APPLICATION_ERROR(-20020, 'Никнейм может содержать только буквы (включая русские), цифры и подчеркивание!');
            RETURN;
        END IF;
        IF p_password IS NULL OR LENGTH(TRIM(p_password)) < 8 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Пароль должен быть не менее 8 символов!');
            RETURN;
        END IF;
        IF LENGTHB(p_password) > 30 THEN
            RAISE_APPLICATION_ERROR(-20021, 'Пароль не должен превышать 30 символов!');
            RETURN;
        END IF;
        IF INSTR(p_password, ' ') > 0 THEN
            RAISE_APPLICATION_ERROR(-20019, 'Пароль не должен содержать пробелы!');
            RETURN;
        END IF;
        SELECT COUNT(*) INTO v_count FROM players WHERE nickname = p_nick;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Никнейм "' || p_nick || '" уже зарегистрирован. Выберите другой никнейм.');
            RETURN;
        END IF;
        BEGIN
            INSERT INTO players (nickname, password_hash) VALUES (p_nick, p_password);
            INSERT INTO player_results (nickname, games_played, games_won, total_points)
            VALUES (p_nick, 0, 0, 0);
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Пользователь создан.');
            DBMS_OUTPUT.PUT_LINE('Никнейм "' || p_nick || '" успешно зарегистрирован. Теперь войдите в игру.');
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20022, 'Ошибка при сохранении данных игрока: ' || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END register_player;

    PROCEDURE login(p_nick VARCHAR2, p_password VARCHAR2) IS
        v_nick VARCHAR2(100);
        v_count NUMBER;
    BEGIN
        check_game_not_started;
        IF p_nick IS NULL OR p_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20005, 'Имя и пароль не могут быть пустыми!');
        END IF;
        v_nick := TRIM(p_nick);
        IF LENGTH(v_nick) = 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Имя пользователя не может быть пустым');
        END IF;
        IF LENGTHB(p_nick) > 100 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Имя пользователя слишком длинное!');
        END IF;
        IF LENGTHB(p_password) > 30 THEN
            RAISE_APPLICATION_ERROR(-20021, 'Пароль не должен превышать 30 символов!');
            RETURN;
        END IF;

        IF g_is_authenticated THEN
            RAISE_APPLICATION_ERROR(-20012, 'Вы уже вошли в игру как "' || g_current_username || '". Сначала выйдите из игры.');
        END IF;

        SELECT COUNT(*) INTO v_count FROM players WHERE nickname = v_nick;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Никнейм "' || v_nick || '" не зарегистрирован. Сначала зарегистрируйтесь.');
        END IF;

        IF verify_password(v_nick, p_password) THEN
            g_current_username := v_nick;
            g_current_password := p_password;
            g_is_authenticated := TRUE;
            g_session_id := SYS_CONTEXT('USERENV', 'SID');
            DBMS_OUTPUT.PUT_LINE('Авторизация успешна для никнейма "' || v_nick || '".');
        ELSE
            RAISE_APPLICATION_ERROR(-20009, 'Неверный пароль для никнейма "' || v_nick || '".');
        END IF;
    EXCEPTION
        WHEN invalid_credentials THEN
            RAISE_APPLICATION_ERROR(-20009, 'Неверный пароль для никнейма "' || v_nick || '".');
    END login;

    PROCEDURE logout IS
    BEGIN
        -- Завершение игры перед разлогиниванием
        exit_game;

        g_current_username := NULL;
        g_current_password := NULL;
        g_is_authenticated := FALSE;
        g_session_id := NULL;
        DBMS_OUTPUT.PUT_LINE('Вы разлогинились из системы. Все данные авторизации сброшены. Для продолжения игры необходимо заново войти с помощью login.');
    END logout;

    PROCEDURE check_nick_set IS
    BEGIN
        check_auth;
    END check_nick_set;

    PROCEDURE set_level(p_level IN VARCHAR2) IS
        v_level NUMBER;
    BEGIN
        check_nick_set;
        check_game_not_started;
        IF p_level IS NULL OR TRIM(p_level) = '' THEN
            RAISE_APPLICATION_ERROR(-20024, 'Уровень не может быть пустым!');
            RETURN;
        END IF;
        BEGIN
            v_level := TO_NUMBER(p_level);
        EXCEPTION
            WHEN VALUE_ERROR THEN
                RAISE_APPLICATION_ERROR(-20025, 'Введено некорректное значение! Уровень должен быть целым числом от 1 до 10.');
                RETURN;
        END;
        IF v_level != TRUNC(v_level) OR v_level NOT BETWEEN 1 AND 10 THEN
            RAISE_APPLICATION_ERROR(-20023, 'Уровень должен быть от 1 до 10');
            RETURN;
        END IF;
        g_player_level := v_level;
        DBMS_OUTPUT.PUT_LINE('Уровень установлен: ' || v_level);
    END;

    PROCEDURE set_pairs(p_pairs IN VARCHAR2) IS
        v_pairs NUMBER;
    BEGIN
        check_nick_set;
        check_game_not_started;
        IF p_pairs IS NULL OR TRIM(p_pairs) = '' THEN
            RAISE_APPLICATION_ERROR(-20034, 'Количество пар не может быть пустым!');
            RETURN;
        END IF;
        BEGIN
            v_pairs := TO_NUMBER(p_pairs);
        EXCEPTION
            WHEN VALUE_ERROR THEN
                RAISE_APPLICATION_ERROR(-20035, 'Введено некорректное значение! Количество пар должно быть целым числом от 5 до 30.');
                RETURN;
        END;
        IF v_pairs != TRUNC(v_pairs) OR v_pairs NOT BETWEEN 5 AND 30 THEN
            RAISE_APPLICATION_ERROR(-20036, 'Количество пар должно быть от 5 до 30!');
            RETURN;
        END IF;
        g_pairs_number := v_pairs;
        DBMS_OUTPUT.PUT_LINE('Количество пар карт установлено: ' || v_pairs);
    END;

    FUNCTION get_level RETURN NUMBER IS
    BEGIN
        check_nick_set;
        check_game_not_started;
        IF g_player_level IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Уровень не установлен');
        END IF;
        RETURN g_player_level;
    END;

    FUNCTION get_nick RETURN VARCHAR2 IS
    BEGIN
        check_nick_set;
        check_game_not_started;
        RETURN g_current_username;
    END;

    FUNCTION is_nick_confirmed RETURN BOOLEAN IS
    BEGIN
        check_nick_set;
        check_game_not_started;
        RETURN g_is_authenticated;
    END;

    PROCEDURE reset_level IS
    BEGIN
        g_player_level := NULL;
    END;

    PROCEDURE exit_game IS
        v_deleted_rows NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF g_job_name IS NOT NULL THEN
            BEGIN
                DBMS_SCHEDULER.DROP_JOB(job_name => g_job_name);
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END IF;

        IF g_current_username IS NOT NULL THEN
            DELETE FROM game_cards WHERE game_nick = g_current_username;
            v_deleted_rows := SQL%ROWCOUNT;
            COMMIT;
        END IF;

        reset_level;
        g_pairs_number := NULL;
        g_job_name := NULL;

        DBMS_OUTPUT.PUT_LINE('Вы вышли из игры. Выберите параметры игры.');
        COMMIT;
    END;

    PROCEDURE start_game IS
        v_values DBMS_SQL.VARCHAR2_TABLE;
        v_all DBMS_SQL.VARCHAR2_TABLE;
        temp VARCHAR2(10);
        j NUMBER;
        v_result_count NUMBER;
        v_deleted_count NUMBER;
        v_remaining_count NUMBER;
    BEGIN
        check_nick_set;
        IF g_player_level IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Уровень не установлен. Задайте уровень с помощью set_level.');
        END IF;
        IF g_pairs_number IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Количество пар не установлено. Задайте количество пар с помощью set_pairs.');
        END IF;
        SELECT COUNT(*) INTO v_result_count FROM player_results WHERE nickname = g_current_username;
        IF v_result_count = 0 THEN
            INSERT INTO player_results (nickname, games_played, games_won, total_points)
            VALUES (g_current_username, 0, 0, 0);
        END IF;
        UPDATE player_results
        SET games_played = games_played + 1
        WHERE nickname = g_current_username;
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Удаляем записи для игрока: ' || g_current_username);
        DELETE FROM game_cards WHERE game_nick = g_current_username;
        v_deleted_count := SQL%ROWCOUNT;
        COMMIT;
        

        SELECT COUNT(*) INTO v_remaining_count FROM game_cards WHERE game_nick = g_current_username;
        IF v_remaining_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20042, 'Не удалось удалить старые записи для игрока ' || g_current_username || '. Осталось ' || v_remaining_count || ' записей.');
        END IF;

        FOR i IN 1..g_pairs_number LOOP
            v_values(i) := TO_CHAR(i, 'FM00');
        END LOOP;
        FOR i IN 1..g_pairs_number LOOP
            v_all(i) := v_values(i);
            v_all(g_pairs_number + i) := v_values(i);
        END LOOP;

        FOR i IN REVERSE 2..v_all.COUNT LOOP
            j := TRUNC(DBMS_RANDOM.VALUE(1, i + 1));
            temp := v_all(i);
            v_all(i) := v_all(j);
            v_all(j) := temp;
        END LOOP;

        FOR i IN 1..v_all.COUNT LOOP
            INSERT INTO game_cards (card_id, game_nick, card_value, is_opened)
            VALUES (i, g_current_username, v_all(i), 'N');
        END LOOP;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Вставлено ' || v_all.COUNT || ' новых записей для игрока ' || g_current_username);

        g_job_name := 'CHECK_TIMEOUT_' || g_current_username || '_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS');
        DBMS_SCHEDULER.CREATE_JOB(
            job_name   => g_job_name,
            job_type   => 'PLSQL_BLOCK',
            job_action => 'BEGIN player_level_pkg.check_move_timeout; END;',
            start_date => SYSTIMESTAMP,
            repeat_interval => 'FREQ=SECONDLY;INTERVAL=5',
            enabled    => TRUE,
            auto_drop  => FALSE
        );
        DBMS_OUTPUT.PUT_LINE('Игровое поле создано. Уровень: ' || g_player_level || ', время на ход: ' || get_move_time_limit || ' сек');
        show_board;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END;

    PROCEDURE show_board IS
        CURSOR c IS
            SELECT card_id, 
                   CASE WHEN is_opened = 'Y' THEN card_value ELSE '***' END AS display_value
            FROM game_cards
            WHERE game_nick = g_current_username
            ORDER BY card_id;
        v_count NUMBER := 0;
    BEGIN
        check_nick_set;
        DBMS_OUTPUT.PUT_LINE('Игровое поле (Уровень: ' || g_player_level || ', время на ход: ' || get_move_time_limit || ' сек):');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
        FOR rec IN c LOOP
            DBMS_OUTPUT.PUT('| ' || RPAD(rec.display_value, 3) || ' |');
            v_count := v_count + 1;
            IF MOD(v_count, 6) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('');
                FOR i IN v_count - 5..v_count LOOP
                    DBMS_OUTPUT.PUT('| ' || LPAD(i, 3) || ' |');
                END LOOP;
                DBMS_OUTPUT.PUT_LINE(CHR(10));
            END IF;
        END LOOP;
        IF MOD(v_count, 6) != 0 THEN
            DBMS_OUTPUT.PUT_LINE('');
            FOR i IN v_count - MOD(v_count, 6) + 1..v_count LOOP
                DBMS_OUTPUT.PUT('| ' || LPAD(i, 3) || ' |');
            END LOOP;
            DBMS_OUTPUT.PUT_LINE(CHR(10));
        END IF;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
    END;

    PROCEDURE check_move_timeout IS
        v_last_move_time TIMESTAMP;
        v_time_limit NUMBER;
        v_time_diff NUMBER;
    BEGIN
        IF g_current_username IS NULL THEN
            RETURN;
        END IF;
        v_time_limit := get_move_time_limit;
        BEGIN
            SELECT MAX(move_timestamp) INTO v_last_move_time
            FROM game_cards
            WHERE game_nick = g_current_username AND move_timestamp IS NOT NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_last_move_time := NULL;
        END;
        IF v_last_move_time IS NOT NULL THEN
            v_time_diff := EXTRACT(SECOND FROM (CURRENT_TIMESTAMP - v_last_move_time));
            IF v_time_diff > v_time_limit THEN
                DBMS_OUTPUT.PUT_LINE('Время на ход (' || v_time_limit || ' сек) истекло для игрока ' || g_current_username || '! Игра завершена. Воспользуйтесь exit_game, чтобы выйти из игры');
                exit_game;
            END IF;
        END IF;
    END;

    PROCEDURE make_move(card_id_1 IN VARCHAR2, card_id_2 IN VARCHAR2) IS
        v_card_1_value VARCHAR2(10);
        v_card_2_value VARCHAR2(10);
        v_card_1_is_opened CHAR(1);
        v_card_2_is_opened CHAR(1);
        v_closed_cards NUMBER;
        v_last_move_time TIMESTAMP;
        v_time_limit NUMBER;
        v_time_diff NUMBER;
        v_game_started NUMBER;
        v_card_id_1 NUMBER;
        v_card_id_2 NUMBER;
    BEGIN
        check_nick_set;
        SELECT COUNT(*) INTO v_game_started FROM game_cards WHERE game_nick = g_current_username;
        IF v_game_started = 0 THEN
            RAISE_APPLICATION_ERROR(-20031, 'Вы не можете сделать ход, пока не начнете игру!');
        END IF;

        IF card_id_1 IS NULL OR card_id_2 IS NULL THEN
            RAISE_APPLICATION_ERROR(-20037, 'ID карт не могут быть пустыми. Введите числа от 1 до ' || (2 * g_pairs_number) || '.');
        END IF;

        BEGIN
            v_card_id_1 := TO_NUMBER(card_id_1);
            v_card_id_2 := TO_NUMBER(card_id_2);
        EXCEPTION
            WHEN VALUE_ERROR THEN
                RAISE_APPLICATION_ERROR(-20038, 'Принимаются только числа в качестве ID карт!');
        END;

        IF v_card_id_1 < 1 OR v_card_id_1 > 2 * g_pairs_number OR v_card_id_2 < 1 OR v_card_id_2 > 2 * g_pairs_number THEN
            RAISE_APPLICATION_ERROR(-20036, 'ID карт должны быть от 1 до ' || (2 * g_pairs_number));
        END IF;

        IF v_card_id_1 = v_card_id_2 THEN
            RAISE_APPLICATION_ERROR(-20015, 'Карточки должны быть разными!');
        END IF;

        v_time_limit := get_move_time_limit;
        BEGIN
            SELECT MAX(move_timestamp) INTO v_last_move_time
            FROM game_cards
            WHERE game_nick = g_current_username AND move_timestamp IS NOT NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_last_move_time := NULL;
        END;

        IF v_last_move_time IS NOT NULL THEN
            v_time_diff := EXTRACT(SECOND FROM (CURRENT_TIMESTAMP - v_last_move_time));
            IF v_time_diff > v_time_limit THEN
                RAISE_APPLICATION_ERROR(-20014, 'Время на ход (' || v_time_limit || ' сек) истекло! Воспользуйтесь exit_game для выхода');
        		exit_game;
            END IF;
        END IF;

        BEGIN
            SELECT card_value, is_opened INTO v_card_1_value, v_card_1_is_opened
            FROM game_cards
            WHERE card_id = v_card_id_1 AND game_nick = g_current_username;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20036, 'Карта с ID ' || v_card_id_1 || ' не существует для текущего игрока.');
        END;

        BEGIN
            SELECT card_value, is_opened INTO v_card_2_value, v_card_2_is_opened
            FROM game_cards
            WHERE card_id = v_card_id_2 AND game_nick = g_current_username;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20036, 'Карта с ID ' || v_card_id_2 || ' не существует для текущего игрока.');
        END;

        IF v_card_1_is_opened = 'Y' OR v_card_2_is_opened = 'Y' THEN
            RAISE_APPLICATION_ERROR(-20016, 'Одна или обе карты уже открыты!');
        END IF;

        UPDATE game_cards 
        SET is_opened = 'Y',
            move_timestamp = CURRENT_TIMESTAMP
        WHERE card_id IN (v_card_id_1, v_card_id_2) 
        AND game_nick = g_current_username;
        COMMIT;

        IF v_card_1_value = v_card_2_value THEN
            DBMS_OUTPUT.PUT_LINE('Карты совпали!');
            show_board;
            SELECT COUNT(*) INTO v_closed_cards
            FROM game_cards
            WHERE game_nick = g_current_username AND is_opened = 'N';
            IF v_closed_cards = 0 THEN
                DBMS_OUTPUT.PUT_LINE('Все карточки найдены!');
                UPDATE player_results
                SET games_won = games_won + 1,
                    total_points = total_points + g_pairs_number
                WHERE nickname = g_current_username;
                COMMIT;
                exit_game;
            END IF;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Карты не совпали. Закрываем обратно.');
            show_board;
            UPDATE game_cards 
            SET is_opened = 'N',
                move_timestamp = CURRENT_TIMESTAMP
            WHERE card_id IN (v_card_id_1, v_card_id_2) 
            AND game_nick = g_current_username;
            COMMIT;
        END IF;
    END;

    PROCEDURE show_top IS
        CURSOR c_top IS 
            SELECT nickname, games_won, total_points 
            FROM player_results 
            ORDER BY total_points DESC 
            FETCH FIRST 20 ROWS ONLY;
        v_position NUMBER := 1;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Топ 20 игроков по очкам:');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
        DBMS_OUTPUT.PUT_LINE('Место | Никнейм         | Победы | Очки');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
        FOR rec IN c_top LOOP
            DBMS_OUTPUT.PUT_LINE(LPAD(v_position, 6) || '  |    ' || RPAD(rec.nickname, 15) || ' | ' || LPAD(rec.games_won, 6) || ' | ' || LPAD(rec.total_points, 6));
            v_position := v_position + 1;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
    END;

    PROCEDURE track_game_status IS
        v_last_move_time TIMESTAMP;
        v_time_limit NUMBER;
        v_time_remaining NUMBER;
        v_game_started NUMBER;
    BEGIN
        IF NOT g_is_authenticated THEN
            RAISE_APPLICATION_ERROR(-20001, 'Вы не вошли в игру! Сначала выполните login().');
        END IF;
        IF g_player_level IS NULL THEN
            RAISE_APPLICATION_ERROR(-20027, 'Уровень не установлен!');
            RETURN;
        END IF;
        IF g_pairs_number IS NULL THEN
            RAISE_APPLICATION_ERROR(-20026, 'Количество пар карточек не установлено! Сначала выполните set_pairs()');
            RETURN;
        END IF;
        SELECT COUNT(*) INTO v_game_started FROM game_cards WHERE game_nick = g_current_username;
        IF v_game_started = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Игра еще не начата! Сделайте первый ход.');
            DBMS_OUTPUT.PUT_LINE(RPAD('-', 50, '-'));
            DBMS_OUTPUT.PUT_LINE('Уровень: ' || g_player_level);
            DBMS_OUTPUT.PUT_LINE('Количество пар карт: ' || g_pairs_number);
            DBMS_OUTPUT.PUT_LINE(RPAD('-', 50, '-'));
            RETURN;
        END IF;
        v_time_limit := get_move_time_limit;
        BEGIN
            SELECT MAX(move_timestamp) INTO v_last_move_time
            FROM game_cards
            WHERE game_nick = g_current_username AND move_timestamp IS NOT NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_last_move_time := NULL;
        END;
        IF v_last_move_time IS NOT NULL THEN
            v_time_remaining := v_time_limit - EXTRACT(SECOND FROM (CURRENT_TIMESTAMP - v_last_move_time));
            IF v_time_remaining < 0 THEN
                v_time_remaining := 0;
            END IF;
        ELSE
            v_time_remaining := v_time_limit;
        END IF;
        IF v_time_remaining = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Время вышло! Игра завершается.');
            exit_game;
            RETURN;
        END IF;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 50, '-'));
        DBMS_OUTPUT.PUT_LINE('Игрок: ' || g_current_username);
        DBMS_OUTPUT.PUT_LINE('Уровень: ' || g_player_level);
        DBMS_OUTPUT.PUT_LINE('Количество пар карт: ' || g_pairs_number);
        DBMS_OUTPUT.PUT_LINE('Время на ход: ' || v_time_remaining || ' сек');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 50, '-'));
    END;
END player_level_pkg;
