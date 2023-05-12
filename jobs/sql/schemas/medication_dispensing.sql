CREATE TABLE medication_dispensing
(
emr_id varchar(50),
encounter_id varchar(50),
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
drug_name varchar(500),
dose int,
dose_units varchar(30),
quantity int,
quantity_units varchar(30),
refills int,
dosing_instructions varchar(500),
duration int,
duration_unit varchar(50),
frequency varchar(100)
);