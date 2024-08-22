CREATE TABLE mh_patients
(
    patient_program_id      varchar(25),
    patient_id              varchar(25),
    emr_id                  varchar(50),
    emr_id_deprecated       varchar(30),
    dob                     date,
    gender                  varchar(50),
    town                    varchar(500),
    referral                varchar(500),
    program_enrollment_date date,
    interventions           varchar(1000),
    index_asc               int,
    index_desc              int
);