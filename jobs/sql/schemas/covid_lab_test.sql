CREATE TABLE covid_lab_test
(
    patient_id         INT,
    encounter_id       INT,
    obs_id             INT,
    encounter_date     DATE,
    location           TEXT,
    encounter_type     VARCHAR(255),
    date_entered       DATETIME,
    user_entered       VARCHAR(50),
    specimen_date      DATE,
    date_for_reporting DATE,
    specimen_source    VARCHAR(255),
    antibody           VARCHAR(11),
    antibody_results   VARCHAR(255),
    antigen            VARCHAR(11),
    antigen_results    VARCHAR(255),
    pcr                VARCHAR(11),
    pcr_results        VARCHAR(255),
    genexpert          VARCHAR(11),
    genexpert_results  VARCHAR(255)
);