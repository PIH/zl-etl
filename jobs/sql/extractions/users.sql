SET sql_safe_updates = 0;

DROP TEMPORARY TABLE IF EXISTS temp_users;

CREATE TEMPORARY TABLE temp_users (
    username            varchar(50) primary key,
    first_name          varchar(50),
    last_name           varchar(50),
    account_enabled     bit,
    created_date        datetime,
    created_by          varchar(50),
    provider_type       varchar(255),
    last_login_date     datetime,
    num_logins_recorded int
);

INSERT INTO temp_users(username, first_name, last_name, account_enabled, created_date, created_by, provider_type)
SELECT      username(u.user_id),
            person_given_name(u.person_id),
            person_family_name(u.person_id),
            if(u.retired, false, true),
            u.date_created,
            username(u.creator),
            (select group_concat(pp.name) from provider p inner join providermanagement_provider_role pp on p.provider_role_id = pp.provider_role_id where p.person_id = u.person_id)
FROM        users u
;

UPDATE temp_users u INNER JOIN (
    SELECT      e.username, max(e.event_datetime) as last_login_date, count(e.event_datetime) as num_logins
    FROM        authentication_event_log e
    GROUP BY    e.user_id
    ) l ON u.username = l.username
SET u.last_login_date = l.last_login_date, u.num_logins_recorded = l.num_logins
;

-- Select all out of table
SELECT * FROM temp_users;