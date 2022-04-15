CREATE TABLE covid_diagnoses
(
    emr_id                 VARCHAR(25),
    encounter_id           INT,
    encounter_type         VARCHAR(255),
    location               TEXT,
    encounter_date         DATE,
    date_entered           DATETIME,
    user_entered           VARCHAR(50),
    diagnosis_order        TEXT,
    diagnosis              TEXT,
    diagnosis_confirmation TEXT,
    covid19_diagnosis      VARCHAR(255)
);
