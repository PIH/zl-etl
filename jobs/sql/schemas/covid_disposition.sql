CREATE TABLE covid_disposition
(
    emr_id              VARCHAR(25),
    encounter_id        INT,
    encounter_type      VARCHAR(255),
    location            TEXT,
    encounter_date      DATE,
    date_entered        DATETIME,
    user_entered        VARCHAR(50),
    disposition         VARCHAR(255),
    discharge_condition VARCHAR(255),
    index_asc           INT,
    index_desc          INT
);
