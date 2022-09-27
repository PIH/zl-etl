CREATE TABLE users
(
    username            varchar(50),
    first_name          varchar(50),
    last_name           varchar(50),
    account_enabled     bit,
    created_date        datetime,
    created_by          varchar(50),
    provider_type       varchar(50),
    last_login_date     datetime,
    num_logins_recorded int
)
;




