CREATE TABLE mh_medications
(
    encounter_id            varchar(25),
    patient_id              varchar(25),
    emr_id                  varchar(50),
    encounter_datetime      datetime,
    encounter_location_name varchar(50),
    facility                varchar(255),
    visit_id                varchar(25),
    visit_location          varchar(255),
    encounter_creator       varchar(50),
    provider                varchar(50),
    medication_name         varchar(500),
    dosage                  int,
    dosage_unit             varchar(50)
);
