CREATE TABLE mh_diagnoses
(
    encounter_id            varchar(25),
    patient_id              varchar(25),
    emr_id                  varchar(50),
    encounter_datetime      datetime,
    encounter_location_name varchar(50),
    encounter_creator       text,
    provider                text,
    age_at_enc              float,
    gender                  varchar(50),
    diagnosis               varchar(255)
);
