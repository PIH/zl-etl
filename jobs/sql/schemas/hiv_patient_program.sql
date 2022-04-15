create table hiv_patient_program
(
    patient_program_id INT,
    emr_id             VARCHAR(255),
    date_enrolled      DATE,
    date_completed     DATE,
    location           VARCHAR(255),
    outcome            VARCHAR(255)
);
