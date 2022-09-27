SET sql_safe_updates = 0;

DROP TEMPORARY TABLE IF EXISTS temp_user_logins;

CREATE TEMPORARY TABLE temp_user_logins (
                                            session_id char(36) primary key,
                                            username varchar(50),
                                            date_logged_in datetime,
                                            date_logged_out datetime,
                                            date_session_destroyed datetime,
                                            active_duration_minutes int
);

-- Right now, we are only interested in successful logins.
-- Once we introduce Multi-Factor authentication, this may or may not change for this table
INSERT INTO temp_user_logins(session_id, username, date_logged_in)
SELECT  authentication_session_id, username, event_datetime
FROM    authentication_event_log
WHERE   event_type = 'AUTHENTICATION_LOGIN_SUCCEEDED'
;

-- Update date_session_destroyed
UPDATE temp_user_logins s inner join (
    select      l.authentication_session_id as id, max(l.event_datetime) as event_datetime
    from        authentication_event_log l
    where       l.event_type = 'AUTHENTICATION_SESSION_DESTROYED'
    group by    l.authentication_session_id
    ) a on s.session_id = a.id
    SET s.date_session_destroyed = a.event_datetime
;

-- Update date_logged_out
UPDATE temp_user_logins s inner join authentication_event_log l on s.session_id = l.authentication_session_id
    SET s.date_logged_out = l.event_datetime
WHERE l.event_type = 'AUTHENTICATION_LOGOUT_SUCCEEDED'
;

-- Calculate active_duration_minutes

-- If we have date_logged_in and date_logged_out, we use those
UPDATE temp_user_logins s
SET active_duration_minutes = timestampdiff(MINUTE, date_logged_in, date_logged_out)
WHERE date_logged_out is not null and date_logged_in is not null
;

-- If not, we use date_logged_in until 30 minutes prior to session expiry, which is inferred as last activity
UPDATE temp_user_logins s
SET active_duration_minutes = (timestampdiff(MINUTE, date_logged_in, date_session_destroyed) - 30)
WHERE active_duration_minutes is null and date_session_destroyed is not null and date_logged_in is not null
;

-- If the computed duration above is less than zero, do not adjust for session timeout (likely server restart)
UPDATE temp_user_logins s
SET active_duration_minutes = timestampdiff(MINUTE, date_logged_in, date_session_destroyed)
WHERE active_duration_minutes < 0
;

-- Select all out of table
SELECT * FROM temp_user_logins;