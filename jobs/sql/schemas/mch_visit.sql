CREATE TABLE mch_visit
(
    patient_id                       INT,
    emr_id                           VARCHAR(25),
    encounter_id                     INT,
    visit_date                       DATE,
    visit_site                       VARCHAR(100),
    visit_type                       VARCHAR(100),
    consultation_type                VARCHAR(30),
    consultation_type_fp             VARCHAR(30),
    age_at_visit                     FLOAT,
    date_entered                     DATETIME,
    user_entered                     VARCHAR(50),
    examining_doctor                 VARCHAR(100),
    pregnant                         BIT,
    breastfeeding                    VARCHAR(5),
    pregnant_lmp                     DATE,
    pregnant_edd                     DATE,
    next_visit_date                  DATE,
    triage_level                     VARCHAR(10),
    referral_type                    TEXT,
    referral_type_other              TEXT,
    implant_inserted                 BIT,
    IUD_inserted                     BIT,
    tubal_ligation_completed         BIT,
    abortion_completed               BIT,
    bcg_1                            DATE,
    polio_0                          DATE,
    polio_1                          DATE,
    polio_2                          DATE,
    polio_3                          DATE,
    polio_booster_1                  DATE,
    polio_booster_2                  DATE,
    pentavalent_1                    DATE,
    pentavalent_2                    DATE,
    pentavalent_3                    DATE,
    rotavirus_1                      DATE,
    rotavirus_2                      DATE,
    mmr_1                            DATE,
    tetanus_0                        DATE,
    tetanus_1                        DATE,
    tetanus_2                        DATE,
    tetanus_3                        DATE,
    tetanus_booster_1                DATE,
    tetanus_booster_2                DATE,
    gyno_exam                        BIT,
    wh_exam                          BIT,
    previous_history                 TEXT,
    hiv_test_admin                   BIT,
    cervical_cancer_screening_date   DATE,
    cervical_cancer_screening_result BIT,
    primary_diagnosis                TEXT,
    secondary_diagnosis              TEXT,
    diagnosis_non_coded              TEXT,
    procedures                       TEXT,
    procedures_other                 TEXT,
    medication_order                 TEXT,
    family_planning_use              BIT,
    family_planning_method           VARCHAR(255),
    fp_counseling_received           BIT,
    risk_factors                     TEXT,
    index_asc                        INT,
    index_desc                       INT
);