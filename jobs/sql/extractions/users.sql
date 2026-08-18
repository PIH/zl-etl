SET sql_safe_updates = 0;

DROP TEMPORARY TABLE IF EXISTS temp_users;

CREATE TEMPORARY TABLE temp_users (
    user_id             int,
    username            varchar(50),
    first_name          varchar(50),
    last_name           varchar(50),
    email               varchar(500),
    account_enabled     bit,
    created_date        datetime,
    created_by          varchar(50),
    provider_type       varchar(255),
    last_login_date     datetime,
    num_logins_recorded int,
    mfa_status          varchar(50),
    uuid                char(38),
    provider_uuid       char(38)
);

INSERT INTO temp_users(user_id, username, first_name, last_name, account_enabled, created_date, created_by, provider_type, email, uuid, provider_uuid)
SELECT      u.user_id,
            username(u.user_id),
            person_given_name(u.person_id),
            person_family_name(u.person_id),
            if(u.retired, false, true),
            u.date_created,
            username(u.creator),
            provider_role_name(prov.provider_role_id),
            u.email,
            u.uuid,
            prov.uuid
FROM        users u
LEFT JOIN   provider prov
                ON  prov.person_id = u.person_id
                AND prov.provider_id = (
                        SELECT   p2.provider_id
                        FROM     provider p2
                        WHERE    p2.person_id = u.person_id
                        ORDER BY p2.retired ASC, p2.provider_id DESC
                        LIMIT    1
                    )
;

UPDATE temp_users u SET u.last_login_date = user_latest_login(u.user_id);
UPDATE temp_users u SET u.num_logins_recorded = user_num_logins(u.user_id);
UPDATE temp_users u SET u.mfa_status = user_property_value(u.user_id, 'authentication.secondaryType', 'disabled');
UPDATE temp_users u SET u.mfa_status = 'question' where u.mfa_status = 'secret';
UPDATE temp_users u SET u.mfa_status = 'authenticator' where u.mfa_status = 'totp';

ALTER TABLE temp_users DROP COLUMN user_id;

-- Select all out of table
SELECT * FROM temp_users;