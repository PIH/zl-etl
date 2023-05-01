CREATE TABLE oncology_treatment_plan 
(
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
treatment_intent varchar(30),
cancer_stage varchar(30),
plan_details varchar(500)
);