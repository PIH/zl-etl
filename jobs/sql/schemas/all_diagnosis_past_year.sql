
CREATE TABLE all_diagnosis_past_year
(
patient_id int,
dossierId varchar(50),
patient_primary_id varchar(50),
loc_registered varchar(100),
unknown_patient varchar(10),
gender char(1),
age_at_encounter int,
department varchar(50),
commune varchar(50),
SECTION varchar(50),
locality varchar(50),
street_landmark varchar(50),
encounter_id int,
encounter_location varchar(50),
obs_id int,
obs_datetime datetime,
entered_by varchar(50),
provider varchar(50),
diagnosis_entered varchar(50),
dx_order varchar(50),
certainty varchar(50),
coded varchar(10),
diagnosis_concept int,
diagnosis_coded_fr varchar(100),
icd10_code varchar(50),
notifiable int,
urgent int,
santeFamn int,
psychological int,
pediatric int,
outpatient int,
ncd int,
non_diagnosis int,
ed int,
age_restricted int,
oncology int,
date_created datetime,
retrospective int,
visit_id int,
birthdate date,
birthdate_estimated int,
encounter_type varchar(50),
section_communale_CDC_ID varchar(50)
);