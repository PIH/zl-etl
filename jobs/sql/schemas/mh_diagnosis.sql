CREATE TABLE mh_diagnosis 
(
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location_name varchar(50),
encounter_creator varchar(50),
provider varchar(50),
diagnosis varchar(100)
);