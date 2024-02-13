CREATE TABLE all_patients
(
emr_id varchar(50),
hiv_emr_id varchar(50),
dossier_id varchar(50),
reg_location varchar(50),
reg_date date,
user_entered varchar(50),
first_encounter_date date,
last_encounter_date date, 
name varchar(50),
family_name varchar(50),
dob date,
dob_estimated bit,
gender varchar(2),
dead bit,
death_date date,
cause_of_death varchar(100)
)
;