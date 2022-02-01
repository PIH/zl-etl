create table hiv_patient
(
    patient_id                     INT,
    zl_emr_id                      VARCHAR(255),
    hivemr_v1_id                   VARCHAR(255),
    hiv_dossier_id                 VARCHAR(255),
    given_name                     VARCHAR(50),
    family_name                    VARCHAR(50),
    gender                         VARCHAR(50),
    birthdate                      DATE,
    age                            FLOAT,
    birthplace_commune             VARCHAR(255),
    birthplace_sc                  VARCHAR(255),
    birthplace_locality            VARCHAR(255),
    birthplace_province            VARCHAR(255),
    initial_enrollment_location    VARCHAR(255),
    latest_enrollment_location     VARCHAR(255),
    marital_status                 CHAR(60),
    occupation                     VARCHAR(255),
    agent                          TEXT,
    mothers_first_name             VARCHAR(255),
    telephone_number               VARCHAR(60),
    address                        VARCHAR(255),
    department                     VARCHAR(255),
    commune                        VARCHAR(255),
    section_communal               VARCHAR(255),
    locality                       VARCHAR(255),
    street_landmark                TEXT,
    dead                           VARCHAR(1),
    death_date                     DATE,
    cause_of_death                 VARCHAR(255),
    cause_of_death_non_coded       VARCHAR(255),
    patient_msm                    VARCHAR(11),
    patient_sw                     VARCHAR(11),
    patient_pris                   VARCHAR(11),
    patient_trans                  VARCHAR(11),
    patient_idu                    VARCHAR(11),
    parent_firstname               VARCHAR(255),
    parent_lastname                VARCHAR(255),
    parent_relationship            VARCHAR(50),
    socio_people_in_house          INT,
    socio_rooms_in_house           INT,
    socio_roof_type                VARCHAR(20),
    socio_floor_type               VARCHAR(20),
    socio_has_latrine              VARCHAR(20),
    socio_has_radio                VARCHAR(20),
    socio_years_of_education       VARCHAR(50),
    socio_transport_method         VARCHAR(50),
    socio_transport_time           VARCHAR(50),
    socio_transport_walking_time   VARCHAR(50),
    socio_smoker                   VARCHAR(50),
    socio_smoker_years             FLOAT,
    socio_smoker_cigarette_per_day INT,
    socio_alcohol                  VARCHAR(50),
    socio_alcohol_type             TEXT,
    socio_alcohol_drinks_per_day   INT,
    socio_alcohol_days_per_week    INT,
    last_weight                    FLOAT,
    last_weight_date               DATE,
    last_height                    FLOAT,
    last_height_date               DATE,
    last_visit_date                DATE,
    next_visit_date                DATE,
    days_late_to_visit             FLOAT,
    viral_load_date                DATE,
    last_viral_load_date           DATE,
    last_viral_load_numeric        FLOAT,
    last_viral_load_undetectable   FLOAT,
    months_since_last_vl           FLOAT,
    hiv_diagnosis_date             DATE,
    art_start_date                 DATE,
    months_on_art                  FLOAT,
    initial_art_regimen            TEXT,
    art_regimen                    TEXT,
    last_pickup_date               DATE,
    last_pickup_months_dispensed   FLOAT,
    last_pickup_treatment_line     VARCHAR(5),
    next_pickup_date               DATE,
    days_late_to_pickup            FLOAT
);