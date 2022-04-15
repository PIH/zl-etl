CREATE TABLE ovc_program_encounters
(
    emr_id                      VARCHAR(50),
    patient_program_id          INT,
    location                    VARCHAR(255),
    encounter_id                INT,
    encounter_date              DATE,
    date_entered                DATETIME,
    user_entered                VARCHAR(50),
    ovc_program_enrollment_date DATE,
    ovc_program_completion_date DATE,
    program_status_start_date   DATE,
    program_status_end_date     DATE,
    program_status              VARCHAR(255),
    program_outcome             VARCHAR(255),
    hiv_test_date               DATE,
    hiv_status                  VARCHAR(255),
    services                    TEXT,
    other_services              TEXT,
    index_asc_hiv_status        INT,
    index_desc_hiv_status       INT,
    index_asc_program_status    INT,
    index_desc_program_status   INT,
    index_asc_enrollment        INT,
    index_desc_enrollment       INT
);
