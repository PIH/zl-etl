create table hiv_patient_program
(
    hiv_program_id INT,
    emr_id             VARCHAR(255),
    date_enrolled      DATE,
    date_completed     DATE,
    location           VARCHAR(255),
    outcome            VARCHAR(255),
    index_asc          INT,
    index_desc         INT
);
