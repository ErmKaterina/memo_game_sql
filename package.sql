CREATE OR REPLACE PACKAGE player_level_pkg AS
       g_current_username VARCHAR2(100);
       g_current_password VARCHAR2(100);
       g_is_authenticated BOOLEAN := FALSE;

       username_taken EXCEPTION;
       invalid_credentials EXCEPTION;

       PROCEDURE register_player(p_nick VARCHAR2, p_password VARCHAR2);
       PROCEDURE login(p_nick VARCHAR2, p_password VARCHAR2);
       PROCEDURE logout;
       PROCEDURE set_level(p_level IN VARCHAR2);
       PROCEDURE set_pairs(p_pairs IN VARCHAR2);
       FUNCTION get_level RETURN NUMBER;
       FUNCTION get_nick RETURN VARCHAR2;
       FUNCTION is_nick_confirmed RETURN BOOLEAN;
       PROCEDURE reset_level;
       PROCEDURE exit_game;
       PROCEDURE start_game;
       PROCEDURE show_board;
       PROCEDURE check_move_timeout;
       PROCEDURE make_move(card_id_1 IN VARCHAR2, card_id_2 IN VARCHAR2);
       PROCEDURE show_top;
       PROCEDURE track_game_status;
   END player_level_pkg;
