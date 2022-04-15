CREATE TABLE mch_birth
(
    emr_id                       VARCHAR(25),
    mother_emr_id                VARCHAR(25),
    encounter_date               DATE,
    date_entered                 DATETIME,
    user_entered                 VARCHAR(50),
    birth_number                 INT,
    multiples                    INT,
    birth_apgar                  INT,
    birth_outcome                VARCHAR(30),
    birth_weight                 FLOAT,
    birth_neonatal_resuscitation VARCHAR(5),
    birth_macerated_fetus        VARCHAR(5)
);
