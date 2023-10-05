CREATE TABLE mh_encounters
(
emr_id varchar(30),
encounter_id int, 
encounter_date date,
date_entered date,
user_entered varchar(100),
provider_name varchar(100),
psychological_interventions varchar(1000),
inpatient varchar(30),
suicidal_ideation bit,
suicide_attempts bit,
safety_plan varchar(100),
zldsi_score int,
cgi_score int,
ces_dc_score int,
pcl_5_score int,
psc_35_score int,
aims varchar(20), 
whodas_score int,
return_encounter_date date
)
;
