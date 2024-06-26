CREATE TABLE mch_birth
(
    emr_id                       VARCHAR(25),
    encounter_id                 VARCHAR(25),
    encounter_date               DATE,
    date_entered                 DATETIME,
    user_entered                 VARCHAR(50),
    delivery_datetime            DATETIME,
    birth_number                 INT,
    multiples                    INT,
    birth_apgar                  INT,
    birth_outcome                VARCHAR(30),
    birth_weight                 FLOAT,
    birth_neonatal_resuscitation VARCHAR(5),
    birth_macerated_fetus        VARCHAR(5),
    type_of_delivery                varchar(500),
    c_section_maternal_reasons      varchar(500),
    other_c_section_maternal_reasons    text,
    c_section_fetal_reasons         varchar(255),
    other_c_section_fetal_reason        text,
    c_section_obstetrical_reasons   varchar(255),
    other_c_section_obstetrical_reason  text
);
