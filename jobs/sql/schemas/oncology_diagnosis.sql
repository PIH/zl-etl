CREATE TABLE oncology_diagnosis 
(
emr_id varchar(50),
encounter_id varchar(50),
visit_id     varchar(50),
visit_location varchar(255),
encounter_datetime datetime,
encounter_location varchar(100),
facility           varchar(255),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
encounter_type varchar(30),
diagnosis_order varchar(20),
diagnosis varchar(100)
);