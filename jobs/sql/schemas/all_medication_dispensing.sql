CREATE TABLE all_medication_dispensing
(
emr_id varchar(50),
encounter_id varchar(50),
encounter_datetime datetime,
encounter_location varchar(100),
creator varchar(30),
encounter_provider varchar(30),
drug_name varchar(500),
drug_openboxes_code int,
duration int,
duration_unit varchar(20),
quantity_per_dose int,
dose_unit varchar(50),
frequency varchar(50),
quantity_dispensed int,
instructions varchar(500)
);
