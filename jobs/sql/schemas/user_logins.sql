CREATE TABLE user_logins
(
    session_id               char(36),
    username                 varchar(50),
    date_logged_in           datetime,
    date_logged_out          datetime,
    date_session_destroyed   datetime,
    session_duration_minutes int
);