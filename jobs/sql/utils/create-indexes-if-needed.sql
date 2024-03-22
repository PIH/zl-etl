
DROP PROCEDURE IF EXISTS add_index_authentication_event_log_ui #
CREATE PROCEDURE add_index_authentication_event_log_ui()
BEGIN
    if not exists (select * from information_schema.statistics WHERE index_name='authentication_event_log_ui') then
        create index authentication_event_log_ui on authentication_event_log(user_id);
    end if;
END #
CALL add_index_authentication_event_log_ui #
DROP PROCEDURE IF EXISTS add_index_authentication_event_log_ui #

DROP PROCEDURE IF EXISTS add_index_authentication_event_log_ui_et #
CREATE PROCEDURE add_index_authentication_event_log_ui_et()
BEGIN
    if not exists (select * from information_schema.statistics WHERE index_name='authentication_event_log_ui_et') then
        create index authentication_event_log_ui_et on authentication_event_log(user_id, event_type);
    end if;
END #
CALL add_index_authentication_event_log_ui_et #
DROP PROCEDURE IF EXISTS add_index_authentication_event_log_ui_et #
