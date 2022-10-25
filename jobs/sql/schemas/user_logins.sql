CREATE TABLE user_logins
(
    login_id                char(36),
    username                varchar(50),
    date_logged_in          datetime,
    date_logged_out         datetime,
    date_expired            datetime,
    active_duration_minutes int
);